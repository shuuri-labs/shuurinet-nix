{ config, lib, pkgs, ... }:
let
  service = "transmission";

  homelab = config.homelab;
  storage = config.homelab.system.storage;
  cfg     = homelab.services.${service};

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options // {
    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = storage.directories.downloads;
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
      homelab.services.${service} = {
        port = lib.mkDefault 9091;
        extraGroups = lib.mkDefault [ storage.accessGroups.downloads.name ];

        fqdn.topLevel = lib.mkDefault "trans";
      };

      homelab.lib.vpnConfinement.services.${service}.enable = lib.mkDefault true;

      services.${service} = {
        enable = true;
        user = cfg.user;
        group = cfg.group;
        
        package = pkgs.transmission_4;

        settings = {
          download-dir = cfg.downloadDir;
          incomplete-dir-enabled = false;

          rpc-bind-address = if   homelab.lib.vpnConfinement.enable 
                             then homelab.lib.vpnConfinement.namespace.address 
                             else "127.0.0.1";
          rpc-port = cfg.port; 

          "rpc-authentication-required" = false; # TODO enable and add pw secret
          "rpc-username" = cfg.rpcUsername;
          "rpc-password" = cfg.rpcPassword;

          "ratio-limit-enabled" = true;
          "ratio-limit" = 2.0;
        };
      };

      users.users.${service}.extraGroups = cfg.extraGroups;
    })
  ];
}