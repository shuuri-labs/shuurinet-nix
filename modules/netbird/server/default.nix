{ config, lib, pkgs, ... }:
let 
  cfg = config.netbird.server;
in
{
  options.netbird.server = {
    enable = lib.mkEnableOption "Enable netbird server";

    coturn = {
      passwordFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to the coturn password file";
      };
    };

    management = {
      oidcConfigEndpoint = lib.mkOption {
        type = lib.types.str;
        description = "OIDC configuration endpoint";
      };
    };
  };
  
  config = {
    services.netbird = {

      server = {
        enable = true;

        dashboard = {
          enableNginx = true;
          settings = {
            # AUTH_AUTHORITY = "https://${globals.services.kanidm.domain}/oauth2/openid/netbird";
            # Fix Kanidm not supporting fragmented URIs
            # AUTH_REDIRECT_URI = "/peers";
            # AUTH_SILENT_REDIRECT_URI = "/add-peers";


          };
        };

        # relay = {
        #   authSecretFile = config.age.secrets.relaySecret.path;
        #   settings.NB_EXPOSED_ADDRESS = "rels://${globals.services.netbird.domain}:443";
        # };
        # ??? where is this coming from. optionis don't seem to exist. see github link below

        coturn = {
          enable = true;
          passwordFile = cfg.coturn.passwordFile;
        };

        management = {
          port = 3000;
          dnsDomain = "internal.invalid";
          singleAccountModeDomain = "netbird.patrick";
          oidcConfigEndpoint = cfg.management.oidcConfigEndpoint;
          settings = {
            TURNConfig = {
              Secret._secret = config.age.secrets.coturnSecret.path;
            };
            Signal.URI = "${globals.services.netbird.domain}:443";
            HttpConfig = {
              # This is not possible
              # failed validating JWT token sent from peer y1ParZkbzVMQGeU/KMycYl75v90i2O6EwgO1YQZnSFs= with error rpc error: code = Internal desc = unable to fetch account with claims, err: user ID is empty
              #AuthUserIDClaim = "preferred_username";
              AuthAudience = "netbird";
            };

            DataStoreEncryptionKey._secret = config.age.secrets.dataEnc.path;
          };
        };
      };
    };
  };
}

# https://github.com/PatrickDaG/nix-config/blob/ac6a608a935495f768e29c7ab690f6abadb1eadf/config/services/netbird.nix#L89