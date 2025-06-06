{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.homelab.reverseProxy;
  
  # Create virtual hosts for all enabled proxy hosts
  virtualHosts = lib.mapAttrs' (hostName: hostConfig: {
    name = hostConfig.proxy.domain;
    value = {
      extraConfig = ''
        reverse_proxy ${hostConfig.proxy.backend.address}:${toString hostConfig.proxy.backend.port}

        tls {
          ${cfg.caddy.tls}
        }
        ${cfg.caddy.extraConfig}
      '';
    };
  }) cfg.enabledProxyHosts;
in
{
  options.homelab.reverseProxy.caddy = {
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
      virtualHosts = virtualHosts;
    };
  };
}
