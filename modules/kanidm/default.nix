{ config, lib, pkgs, ... }:
let
  cfg = config.kanidm;
in
{
  options.kanidm = {
    enable = lib.mkEnableOption "kanidm";

    adminPasswordFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the file containing the admin password";
    };

    idmAdminPasswordFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the file containing the IDM admin password";
    };

    tls_chain = lib.mkOption {
      type = lib.types.path;
      description = "Path to the TLS chain file";
    };

    tls_key = lib.mkOption {
      type = lib.types.path;
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain of the Kanidm instance";
    };

    origin = lib.mkOption {
      type = lib.types.str;
      description = "The origin of the Kanidm instance";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.kanidmWithSecretProvisioning_1_5
    ];

    services.kanidm = {
      package = pkgs.kanidmWithSecretProvisioning_1_5;

      enableServer = true;

      serverSettings = {
        tls_chain = cfg.tls_chain;
        tls_key = cfg.tls_key;
        ldapbindaddress = "127.0.0.1:636";
        domain = cfg.domain;
        origin = cfg.origin;
        trust_x_forward_for = true;
      };

      provision = { 
        enable = true;

        adminPasswordFile = cfg.adminPasswordFile;
        idmAdminPasswordFile = cfg.idmAdminPasswordFile;

        persons = {
          "ashley" = {
            displayName = "Ashley";
            present = true;
            mailAddresses = [ "ashley@shuuri.net" ];
          };
        };

        groups = {
          "jellyfin-access" = {
            present = true;
            members = [ "ashley" ]; # can also add via provision.persons.<name>.groups
          };
        };
      };
    };
  };
}

# you can 'login' to the admin account in the terminal with:
# sudo kanidm login -D admin --url https://127.0.0.1:8443

# set the instance name that shows up in the UI. can't see a nix option for this (currently, 12/05/2025):
# sudo kanidm system domain set-displayname --url https://127.0.0.1:8443  "shuurinet London"

# users (even those defined in provision.persons) need to be enrolled manually:
# sudo kanidmd recover-account <username>
# sudo kanidm login -D <username> --url https://127.0.0.1:8443