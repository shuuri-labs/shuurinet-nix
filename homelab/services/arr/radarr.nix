{ config, lib, pkgs, ... }:
let
  service = "radarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
  commonUsersGroups = import ../common-users-groups.nix { inherit lib config service; };
in
{
  options.homelab.services.${service} = common.options // {
    # --- Common Overrides ---
    
    port = lib.mkOption {
      type = lib.types.int;
      default = 7878;
      description = "Port to run the ${service} service on";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ 
        homelab.storage.accessGroups.downloads.name 
      ];
      description = "Additional groups for ${service} user";
    };

    # --- ${service} Specific ---

    group = lib.mkOption {
      type = lib.types.str;
      default = homelab.storage.accessGroups.media.name;
      description = "Primary group for ${service} user";
    };
  };

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      services.${service} = {
        enable = true;
        group = cfg.group;
        settings = {
          server.port = cfg.port;
        };
      };

      users.users.${service}.extraGroups = cfg.extraGroups;
      systemd.services.${service}.serviceConfig.UMask = "0002";
    })
  ];
}