{ config, lib, pkgs, ... }:
let
  service = "jellyfin";

  homelab = config.homelab;
  cfg = homelab.services.${service};

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options;

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      homelab.services.${service} = {
        port = lib.mkDefault 8096;
        fqdn.topLevel = lib.mkDefault "jelly";
      };

      homelab.lib.dashboard.entries.${service} = {
        section = "Media";
        description = "Media Server";
        widget = {
          type = "jellyfin";
          url = "http://${cfg.address}:${toString cfg.port}";
          key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
        };
      };

      services.${service} = {
        enable = true;
        user = cfg.user;
        group = cfg.group;
      };
    })
  ];
}