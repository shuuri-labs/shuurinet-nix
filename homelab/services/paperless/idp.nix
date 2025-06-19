{ config, lib, pkgs, service, ... }:
let
  homelab = config.homelab;
  cfg     = config.homelab.services.${service};
in
{
  config = lib.mkIf (cfg.enable && cfg.idp.enable && homelab.lib.idp.enable) {
    age.secrets.paperless-ngx-client-secret = {
      file = "/home/ashley/shuurinet-nix/secrets/kanidm-netbird-client-secret.age";
      owner = "kanidm";
      group = "kanidm";
    };

    homelab = {
      lib = {
        idp.services.inputs.${service} = {
          enable = true;
          originUrls = [
            "https://${cfg.fqdn.final}/accounts/oidc/${homelab.lib.idp.provider}/login/callback/"
          ];
          public = false;
          extraAttributes = {
            allowInsecureClientDisablePkce = true;
            basicSecretFile = config.age.secrets.paperless-ngx-client-secret.path;
          };
        };
      };
    };

    services.${service} = {
      settings = {
        PAPERLESS_SOCIALACCOUNT_PROVIDERS = builtins.toJSON {
          "openid_connect" = {
            APPS = [
              { 
                provider_id = homelab.lib.idp.provider; 
                name = homelab.lib.idp.provider; 
                client_id = service; 
                secret = "STKCu9aeeZ/nAlA0UvYHPmAbFefUw82KMQ/sw5nukfk="; # TODO: extract
                settings = { 
                  server_url = homelab.lib.idp.services.outputs.${service}.oidc.serverUrl;
                }; 
              }
            ];
          };
        };
        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      };
    };
  };
}