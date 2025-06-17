{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.homelab.lib.reverseProxy;
  
  # Create virtual hosts for all enabled proxy hosts
  virtualHosts = lib.mapAttrs' (hostName: hostConfig: {
    name = hostConfig.domain;
    value = {
      extraConfig = ''
        reverse_proxy ${hostConfig.backend.address}:${toString hostConfig.backend.port} {
          ${hostConfig.extraConfig}
        }

        tls {
          ${cfg.caddy.tls}
        }
      '';
    };
  });
in
{
  options.homelab.lib.reverseProxy.caddy = {
    environmentFile = mkOption {
      type = types.str;
      description = "Path to environment file for Caddy";
    };

    tls = mkOption {
      type = types.str;
      default = "dns cloudflare {env.CF_API_KEY_TOKEN}";
      description = "TLS configuration for Caddy";
    };

    extraConfig = mkOption {
      type = types.str;
      default = "";
      description = "Additional Caddy configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
        hash = "sha256-Gsuo+ripJSgKSYOM9/yl6Kt/6BFCA6BuTDvPdteinAI=";
      };
      environmentFile = cfg.caddy.environmentFile;
      virtualHosts = virtualHosts cfg.enabledProxyHosts;
    };
  };
}
