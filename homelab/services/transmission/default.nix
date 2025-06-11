{ config, lib, pkgs, ... }:
let
  service = "transmission";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options // {
    # --- Common Overrides ---

    port = lib.mkOption {
      type = lib.types.int;
      default = 9091;
      description = "Port to run the ${service} service on";
    };

    domain = common.options.domain // {
      topLevel = lib.mkOption {
        type = lib.types.str;
        default = "trans";
      };
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ homelab.storage.accessGroups.downloads.name ];
      description = "Groups to add the ${service} user to";
    };

    # --- ${service} Specific  ---

    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = homelab.storage.directories.downloads;
      description = "Directory to store downloads in";
    };

    rpcUsername = lib.mkOption {
      type = lib.types.str;
      default = "ashley";
      description = "Username to access the ${service} web UI";
    };

    rpcPassword = lib.mkOption {
      type = lib.types.str;
      default = "transmission";
      description = "Password to access the ${service} web UI";
    };
  };

  config = lib.mkMerge [
    common.config
  
    
    (lib.mkIf cfg.enable {
      services.${service} = {
        enable = true;
        package = pkgs.transmission_4;

        settings = {
          download-dir = cfg.downloadDir;
          incomplete-dir-enabled = false;

          rpc-bind-address = if   homelab.vpnConfinement.enable 
                             then homelab.vpnConfinement.namespace.address 
                             else "127.0.0.1";
          rpc-port = cfg.port; 

          "rpc-authentication-required" = false; # TODO enable and add pw secret
          "rpc-username" = cfg.rpcUsername;
          "rpc-password" = cfg.rpcPassword;

          "ratio-limit-enabled" = true;
          "ratio-limit" = 2.0;
        };
      };

      # Overriding in options doesn't work so we set it here - perhaps because vpnConfinement 
      # is an imported submodule in common.nix?
      homelab.services.${service}.vpnConfinement.enable = true;

      users.users.${service}.extraGroups = cfg.extraGroups;
    })
  ];
}