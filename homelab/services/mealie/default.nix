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
      };

      homelab.idp.services.${service} = {
        enable = true;
        originUrls = [
          "https://${cfg.fqdn.final}/login"
          "https://${cfg.fqdn.final}/login?direct=1"
        ];
      };

      services.${service} = {
        enable = true;
        port = cfg.port;

        settings = {
          OIDC_AUTH_ENABLED = "True";
          OIDC_SIGNUP_ENABLED = "True";
          OIDC_AUTO_REDIRECT = "True";
          # TODO: need to set config url on service type somehow
          OIDC_CONFIGURATION_URL = "https://${config.homelab.idp.domain}/oauth2/openid/${service}/.well-known/openid-configuration";
          OIDC_CLIENT_ID = config.homelab.idp.services.${service}.oidc.clientId;
          OIDC_CLIENT_SECRET = "";
          OIDC_PROVIDER_NAME = config.homelab.idp.provider;
        };
      };
    })
  ];
}