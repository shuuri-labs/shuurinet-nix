{ config, lib, pkgs, ... }:
let
  service = "jellyfin";
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
        port = lib.mkDefault 8096;
        domain.topLevel = lib.mkDefault "jelly";
      };

      services.${service} = {
        enable = true;
      };
    })
  ];
}