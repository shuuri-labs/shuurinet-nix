{ config, lib, pkgs, ... }:
let
  service = "prowlarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options // {
    port = lib.mkOption {
      type = lib.types.int;
      default = 9696;
      description = "Port to run the ${service} service on";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = homelab.storage.accessGroups.media.name;
      description = "Group to run the ${service} service as";
    };
  };

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      services.${service} = {
        enable = true;
        settings = {
          server.port = cfg.port;
        };
      };
    })
  ];
}