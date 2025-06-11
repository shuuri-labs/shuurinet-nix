{ config, lib, pkgs, ... }:
let
  service = "bazarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options // {
    port = lib.mkOption {
      type = lib.types.int;
      default = 6767;
      description = "Port to run the ${service} service on";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = homelab.groups.mediaAccess;
      description = "Group to run the ${service} service as";
    };
  };

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      services.${service} = {
        enable = true;
        port = cfg.port;
        group = cfg.group;
      };
    })
  ];
}