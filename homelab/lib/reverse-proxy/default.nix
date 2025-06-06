{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.homelab.reverseProxy;
  inherit (import ./types.nix { inherit lib; }) hostType;
in
{
  options.homelab.reverseProxy = {
    enable = mkEnableOption "Enable reverse proxy";

    hosts = mkOption {
      type = types.attrsOf hostType;
      default = {};
      description = "Attribute set of hosts to proxy with unified configuration";
      example = {
        "my-service" = {
          domain = "example.com";
          backend = {
            address = "192.168.1.100";
            port = 3000;
          };
        };
      };
    };

    # Internal option to expose filtered enabled hosts for other modules
    enabledProxyHosts = mkOption {
      type = types.attrsOf types.unspecified;
      internal = true;
      readOnly = true;
      description = "Internal option containing hosts with proxy enabled";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    
    homelab.reverseProxy.enabledProxyHosts = lib.filterAttrs (name: host: 
      host.enable
    ) cfg.hosts;
  };

  imports = [
    ./caddy.nix
  ];
}