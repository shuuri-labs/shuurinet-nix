# modules/lib/caddy/defaults.nix
{ lib, config, ... }:

with lib;
let
  cfg = config.homelab.services.lib.caddy;
in
{
  options.homelab.reverseProxy.caddy = {
    environmentFile = mkOption {
      type = types.str;
      description = ''Path to environment file for Caddy - should contain CF_API_TOKEN'';
    };
  };

  config = {
    services.caddy = {
      enable  = true; 
      package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
        hash = "sha256-saKJatiBZ4775IV2C5JLOmZ4BwHKFtRZan94aS5pO90=";
      };
      environmentFile = cfg.environmentFile;

      globalConfig = ''
        {
          dns cloudflare {env.CF_API_TOKEN}
        }
      '';
    };
  };
}