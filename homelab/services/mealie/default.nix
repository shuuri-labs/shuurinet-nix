{ config, lib, pkgs, ... }:
let
  service = "mealie";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common    = import ../common.nix { inherit lib config homelab service; };
  addProxy  = import ../../reverse-proxy/add-proxy.nix;
  domainLib = import ../../lib/domain.nix;
in
{
  options.homelab.services.${service} = common.options // {
    port = lib.mkOption {
      type = lib.types.int;
      default = 9001;
      description = "Port to run the ${service} service on";
    };
  };

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      services.${service} = {
        enable = true;
        port = cfg.port;
      };
    })
    
    (lib.mkIf (cfg.enable && cfg.domain.enable) (addProxy {
      address = cfg.address;
      port = cfg.port;
      domain = cfg.domain.final;
    }))
  ];
}