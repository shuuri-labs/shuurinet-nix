{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.idp;
  cfgKanidm = cfg.kanidm;
  homelab = config.homelab;

  idp = "kanidm";

  certs = (import ../utils/mkInternalSslCerts.nix { inherit pkgs lib; })
    .mkCertFor idp cfg.domain;

  enabledUsers = lib.filterAttrs (userName: userConfig: userConfig.enable) cfg.users;
  enabledServices = lib.filterAttrs (serviceName: serviceConfig: serviceConfig.enable) cfg.services;
in
{
  options.homelab.idp.${idp} = {
    adminPasswordFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the file containing the admin password";
    };

    idmAdminPasswordFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the file containing the IDM admin password";
    };

    ldapPort = lib.mkOption {
      type = lib.types.int;
      default = 636;
      description = "LDAP bind port";
    };
  };
  
  config = lib.mkIf cfg.enable {
    homelab = {
      idp = {
        port = 8443;
        provider = idp;
      };

      domainManagement.domains.auth = {
        host = {
          extraConfig = ''
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}

            transport http {
              tls_trusted_ca_certs ${certs.ca}
              tls_client_auth ${certs.cert} ${certs.key}
            }
          '';
        };
      };
    };

    # TODO: create certs module to do this automatically
    security.pki.certificateFiles = [
      "${certs.ca}"
    ];

    environment.systemPackages = [
      pkgs.kanidmWithSecretProvisioning_1_5
    ];
    
    services.${idp} = {
      package = pkgs.kanidmWithSecretProvisioning_1_5;

      enableServer = true;

      serverSettings = {
        tls_chain = certs.cert;
        tls_key = certs.key;
        ldapbindaddress = "127.0.0.1:${toString cfgKanidm.ldapPort}";
        domain = cfg.domain;
        origin = "https://${cfg.domain}";
        trust_x_forward_for = true;
      };

      provision = { 
        enable = true;
        adminPasswordFile = cfgKanidm.adminPasswordFile;
        idmAdminPasswordFile = cfgKanidm.idmAdminPasswordFile;

        persons = lib.mapAttrs (name: config: {
          displayName = config.name;
          present = config.enable;
          mailAddresses = [ config.email ];
        }) enabledUsers;

        groups = lib.mapAttrs' (serviceName: serviceConfig: 
          lib.nameValuePair "${serviceName}-access" {
            present = true;
            members = serviceConfig.members;
          }
        ) enabledServices;

        systems.oauth2 = lib.mapAttrs' (serviceName: serviceConfig: {
          name = serviceName;
          value = {
            displayName = serviceConfig.name;
            present = true;
            public = serviceConfig.public;
            enableLocalhostRedirects = serviceConfig.localhostRedirects;
            
            originUrl = serviceConfig.originUrls;
            originLanding = serviceConfig.originLanding;
            
            scopeMaps = {
              "${serviceName}-access" = serviceConfig.oidc.scopes;
            };
          } // serviceConfig.extraAttributes;
        }) enabledServices;
      };
    };
  };
}

# you can 'login' to the admin account in the terminal with:
# sudo kanidm login -D admin --url https://127.0.0.1:8443

# set the instance name that shows up in the UI. can't see a nix option for this (currently, 12/05/2025):
# sudo kanidm system domain set-displayname --url https://127.0.0.1:8443  "shuurinet London"

# users (even those defined in provision.persons) need to be enrolled manually:
# sudo kanidmd recover-account <username> --url https://127.0.0.1:8443
# sudo kanidm login -D <username> --url https://127.0.0.1:8443

