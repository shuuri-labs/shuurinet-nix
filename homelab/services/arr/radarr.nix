{ config, lib, pkgs, ... }:
let
  service = "radarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
  commonUsersGroups = import ../common-users-groups.nix { inherit lib config service; };
in
{
  options.homelab.services.${service} = common.options;

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      homelab.services.${service} = {
        port = lib.mkDefault 7878;
        group = lib.mkDefault homelab.system.storage.accessGroups.media.name;
        extraGroups = lib.mkDefault [ homelab.system.storage.accessGroups.downloads.name ];
      };

      homelab.lib.dashboard.entries.${service}.section = "Media";

      services.${service} = {
        enable = true;
        user = cfg.user;
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