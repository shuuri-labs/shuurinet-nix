{ config, lib, pkgs, ... }:
let
  service = "jellyseerr";

  homelab = config.homelab;
  cfg    = homelab.services.${service};

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options;

  config = lib.mkMerge [
    common.config

    (lib.mkIf cfg.enable {
      homelab = { 
        services.${service} = {
          port = lib.mkDefault 5055;
          fqdn.topLevel = lib.mkDefault "requests";
        };

        lib = {
          dashboard.entries.${service} = {
            description = "Media Requests";
            section = "Media";
          };
        };
      };

      services.${service} = {
        enable = true;
        port = cfg.port;
      };
    })
  ];
}