{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.idp;
  cfgKanidm = cfg.kanidm;

  homelab = config.homelab;

  idp = "kanidm";

  certs = (import ../lib/utils/mkInternalSslCerts.nix { inherit pkgs lib; })
    .mkCertFor idp cfg.${idp}.domain;

  mkUsers = 
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

    persons = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      description = "Persons to add to the IDM service";
      default = {
        "ashley" = {
          displayName = "Ashley";
          present = true;
          mailAddresses = [ "ashley@shuuri.net" ];
        };
      };
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 8443;
      description = "Port to listen on";
    };

    ldapBindPort = lib.mkOption {
      type = lib.types.int;
      default = 636;
      description = "LDAP bind port";
    };
  };
  
  config = lib.mkIf cfg.enable {
    homelab = {
      idp = {
        port = cfg.port;
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

    environment.systemPackages = [
      pkgs.kanidmWithSecretProvisioning_1_5
    ];

    services.${idp} = {
      package = pkgs.kanidmWithSecretProvisioning_1_5;

      enableServer = true;

      serverSettings = {
        tls_chain = certs.cert;
        tls_key = certs.key;
        ldapbindaddress = "127.0.0.1:${toString cfgKanidm.ldapBindPort}";
        domain = cfg.domain;
        origin = "https://${cfg.domain}";
        trust_x_forward_for = true;
      };

      provision = { 
        enable = true;
        adminPasswordFile = cfg.adminPasswordFile;
        idmAdminPasswordFile = cfg.idmAdminPasswordFile;

        persons = users: lib.mapAttrs' (name: userConfig: {
          name = name;
          value = {
            displayName = userConfig.name;
            present = userConfig.enable;
            mailAddresses = [ userConfig.email ];
          };
        }) cfg.users;

        groups = lib.mapAttrs' (serviceName: serviceConfig: 
          lib.nameValuePair "${serviceName}-access" {
            present = serviceConfig.enable;
            members = serviceConfig.members;
          }
        ) cfg.services;

        systems.oauth2 = lib.mapAttrs' (serviceName: serviceConfig: {
          name = serviceName;
          value = {
          displayName = serviceConfig.name;
          present = serviceConfig.enable;
          public = true;
          enableLocalhostRedirects = true;
          
          originUrl = serviceConfig.originUrls;
          originLanding = serviceConfig.originLanding;
          
          scopeMaps = {
            "${serviceName}-access" = serviceConfig.oidcScopes;
            };
          } // serviceConfig.extraAttributes;
        }) cfg.services;
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

