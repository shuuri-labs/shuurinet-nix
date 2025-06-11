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

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ homelab.groups.mediaAccess ];
      description = "Groups to add the ${service} user to";
    };

    vpnConfinement.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable VPN confinement for the ${service} service";
    };

    # --- ${service} Specific  ---

    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = homelab.directories.downlaods;
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

          rpc-bind-address = if   homelab.lib.vpnConfinement.enable 
                             then homelab.lib.vpnConfinement.namespace.address 
                             else homelab.network.primaryBridge.address;
          rpc-port = cfg.port; 

          "rpc-authentication-required" = false; # TODO enable and add pw secret
          "rpc-username" = cfg.rpcUsername;
          "rpc-password" = cfg.rpcPassword;

          "ratio-limit-enabled" = true;
          "ratio-limit" = 2.0;
        };
      };
    })
  ];
}