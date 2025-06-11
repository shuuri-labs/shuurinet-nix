{ config, lib, pkgs, ... }:
let
  service = "jellyfin";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options // {
    port = lib.mkOption {
      type = lib.types.int;
      default = 8096;
      description = ''
        Port that ${service} service runs on.
        Note the port can't be changed via nix config, 
        you'll need to change it here if changed in ${service} settings.
        The default http port is 8096.
      '';
    };

    domain = common.options.domain // {
      topLevel = lib.mkOption {
        type = lib.types.str;
        default = "jelly";
      };
    };
  };

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      services.${service} = {
        enable = true;
      };
    })
  ];
}