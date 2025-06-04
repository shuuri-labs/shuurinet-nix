{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.homelab.reverseProxy.caddy;
in
{
  options.homelab.reverseProxy.caddy = {
    environmentFile = mkOption {
      type = types.str;
      description = ''Path to environment file for Caddy - should contain CF_API_TOKEN'';
    };
  };

  config = {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.caddy = {
      enable  = true; 
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
        hash = "sha256-Gsuo+ripJSgKSYOM9/yl6Kt/6BFCA6BuTDvPdteinAI=cd sec";
      };
      environmentFile = cfg.environmentFile;
    };
  };
}