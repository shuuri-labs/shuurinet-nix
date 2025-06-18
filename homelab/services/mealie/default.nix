{ config, lib, pkgs, ... }:
let
  service = "mealie";

  homelab = config.homelab;
  cfg    = homelab.services.${service};

  common = import ../common.nix { inherit lib config homelab service; };
  idp    = import ./idp.nix { inherit config lib pkgs service; };
in
{
  options.homelab.services.${service} = common.options;

  config = lib.mkMerge [
    common.config
    idp.config 

    (lib.mkIf cfg.enable {
      homelab = { 
        services.${service} = {
          port = lib.mkDefault 9001;
          idp.enable = lib.mkDefault true;
        };
      };

      services.${service} = {
        enable = true;
        port = cfg.port;
      };
    })
  ];
}