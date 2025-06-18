{ config, lib, pkgs, ... }:
let
  homelab = config.homelab;
  cfg = homelab.lib.idp;
  cfgKanidm = cfg.kanidm;

  certs = (import ../utils/mkInternalSslCerts.nix { inherit pkgs lib; })
    .mkCertFor idp cfg.domain;

  idp = "kanidm";

  enabledUsers = lib.filterAttrs (userName: userConfig: userConfig.enable) cfg.users;
  enabledServices = lib.filterAttrs (serviceName: serviceConfig: serviceConfig.enable) cfg.services.inputs;

  baseOidcServerUrl = "https://${cfg.domain}/oauth2/openid/";
  # OIDC configuration URL is IDP implementation-specific, so we need to compute and set it here
  # For now I can't come up with a better solution than 2 attribute sets - inputs and outputs. Infinite recursion otherwise
  completeServices = lib.mapAttrs (serviceName: serviceConfig:
    serviceConfig // {
      oidc = serviceConfig.oidc // {
        serverUrl = "${baseOidcServerUrl}${serviceName}";
        configurationUrl = "${baseOidcServerUrl}${serviceName}/.well-known/openid-configuration";
      };
    }
  ) enabledServices;
in
{
  options.homelab.lib.idp.${idp} = {
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
    homelab.lib = {
      idp = {
        port = 8443;
        provider = idp;
        services.outputs = completeServices;
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
        ) completeServices;

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
        }) completeServices;
      };
    };
  };
}

# you can 'login' to the admin account in the terminal with:
# sudo kanidm login -D admin --url https://127.0.0.1:8443

# set the instance name that shows up in the UI. can't see a nix option for this (currently, 12/05/2025):
# sudo kanidm system domain set-displayname --url https://127.0.0.1:8443  "shuurinet London"

# users (even those defined in provision.persons, but besides the admin user) need to be enrolled manually:
# sudo kanidmd recover-account <username> --url https://127.0.0.1:8443
# sudo kanidm login -D <username> --url https://127.0.0.1:8443

