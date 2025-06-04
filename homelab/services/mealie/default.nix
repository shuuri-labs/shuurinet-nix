{ config, lib, pkgs, ... }:
let
  service = "mealie";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  addProxy = import ../../reverse-proxy/add-proxy.nix;
in
{
  options.homelab.services.${service} = {
    domain.topLevel = lib.mkOption {
      type    = lib.types.str;
      default = lib.mkDefault "meals";
      description = "Top‐level hostname for Mealie (instead of the generic “mealie”).";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 9001;
      description = "Port to run the service on";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      port = cfg.port;
    } // addProxy {
      address = cfg.address;
      port = cfg.port;
      domain = cfg.domain.final;
    };
  };
}