{ config, lib, pkgs, ... }:
let
  service = "mealie";
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
        port = lib.mkDefault 9001;

        idp = {
          enable = true;

          originUrls = [
            "https://${cfg.domain.final}/login"
            "https://${cfg.domain.final}/login?direct=1"
          ];
        };

        domain.host.extraConfig = ''
          forwarded-allow-ips=${cfg.address}
        '';
      };

      services.${service} = {
        enable = true;
        port = cfg.port;
      };
    })
  ];
}