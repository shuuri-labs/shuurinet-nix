{ config, lib, pkgs, ... }:
let
  service = "immich";

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
          port = lib.mkDefault 2283;
          fqdn.topLevel = lib.mkDefault "photos";
        };

        lib = {
          dashboard.entries.${service} = {
            description = "Photo Gallery";
            section = "Media";
          };
        };
      };

      services.${service} = {
        enable = true;
        port = cfg.port;
        host = cfg.address;
      };
    })
  ];
}