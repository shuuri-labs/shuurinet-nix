{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.homelab.reverseProxy;
in
{
  options.homelab.reverseProxy = {
    enable = mkEnableOption "Enable reverse proxy";

    hosts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          proxy = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to create a reverse proxy for this host";
            };

            domain = mkOption {
              type = types.str;
              description = "Domain name for the reverse proxy";
            };

            backend = {
              address = mkOption {
                type = types.str;
                default = "127.0.0.1";
                description = "Backend server address";
              };

              port = mkOption {
                type = types.int;
                description = "Backend server port";
              };
            };
          };
        };
      });
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
      host.proxy.enable
    ) cfg.hosts;
  };

  imports = [
    ./caddy.nix
  ];
}