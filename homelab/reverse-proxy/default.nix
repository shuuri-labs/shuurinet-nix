{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.homelab.reverseProxy;
  hostOptions = import ./host-options.nix { inherit lib; };
in
{
  imports = [
    ./auto-proxy.nix
  ];

  options.homelab.reverseProxy = {
    enable = mkEnableOption "Enable reverse proxy";

    hosts = mkOption {
      type = types.attrsOf hostOptions.hostType;
      default = {};
      description = "Attribute set of hosts to proxy with unified configuration";
      example = {
        "my-service" = {
          proxy = {
            domain = "example.com";
            backend = {
              address = "192.168.1.100";
              port = 3000;
            };
          };
          dns = {
            targetIp = "1.2.3.4";
            proxied = true;
          };
        };
      };
    };

    caddy = {
      environmentFile = mkOption {
        type = types.str;
        description = ''Path to environment file for Caddy - should contain CF_API_TOKEN'';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.caddy = {
      enable  = true; 
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
        hash = "sha256-Gsuo+ripJSgKSYOM9/yl6Kt/6BFCA6BuTDvPdteinAI=";
      };
      environmentFile = cfg.caddy.environmentFile;
    };
  };
}