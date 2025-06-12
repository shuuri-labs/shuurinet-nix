{ config, lib, pkgs, ... }:
let
  service = "prowlarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options;

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      homelab.services.${service} = {
        port = lib.mkDefault 9696;
        group = lib.mkDefault homelab.storage.accessGroups.media.name;
      };

      services.${service} = {
        enable = true;
        settings = {
          server.port = cfg.port;
        };
      };
    })
  ];
}