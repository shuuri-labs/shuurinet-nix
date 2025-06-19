{ config, lib, pkgs, service, ... }:
let
  homelab = config.homelab;
  cfg     = config.homelab.services.${service};
  oidc    = config.homelab.lib.idp.services.outputs.${service}.oidc;
in
{
  config = lib.mkIf (cfg.enable && cfg.idp.enable && homelab.lib.idp.enable) {
    homelab = { 
      lib = {
        idp.services.inputs.${service} = {
          enable = true;
          originUrls = [
            "https://${cfg.fqdn.final}/login"
            "https://${cfg.fqdn.final}/login?direct=1"
          ];
        };
      };
    };

    services.${service} = {
      settings = {
        OIDC_AUTH_ENABLED = "True";
        OIDC_SIGNUP_ENABLED = "True";
        OIDC_AUTO_REDIRECT = "True";
        OIDC_CONFIGURATION_URL = oidc.configurationUrl;
        OIDC_CLIENT_ID = oidc.clientId;
        OIDC_CLIENT_SECRET = "";
        OIDC_PROVIDER_NAME = homelab.lib.idp.provider;
        OIDC_SCOPES = lib.concatStringsSep " " oidc.scopes;
      };
    };
  };
  
  
}