{ config, lib, pkgs, ... }:
let
  service = "bazarr";
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
        port = lib.mkDefault 6767;
        group = lib.mkDefault homelab.storage.accessGroups.media.name;
      };

      services.${service} = {
        enable = true;
        listenPort = cfg.port;
        user = cfg.user;
        group = cfg.group;
      };
    })
  ];
}