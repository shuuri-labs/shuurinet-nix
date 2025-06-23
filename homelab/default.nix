{ lib, config, pkgs, ... }:
let
  cfg = config.homelab;
in
{
  options.homelab = {
    enable = lib.mkEnableOption "Enable homelab";

    system = {
      isPhysical = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the system is physical or a VM";
      }; # TODO: implement
    };

    domain = {
      sub = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Subdomain to be used to access the homelab services via Caddy reverse proxy";
      };
      
      base = lib.mkOption {
        type = lib.types.str;
        default = "shuuri.net";
        description = "Base domain name to be used to access the homelab services via Caddy reverse proxy";
      };

      fqdn = lib.mkOption {
        type = lib.types.str;
        default = "${config.networking.hostName}.${cfg.domain.base}";
        description = "Fully qualified domain name for this host (ignores subdomain)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    homelab = {
      lib = {
        dashboard = {
          enable = true;
        };

        domainManagement = {
          enable = true;
        };

        dns = {
          globalTargetIp = cfg.system.network.primaryBridge.address;

          cloudflare = {
            enable = true;
          };
        };
      };
    };
  };

  imports = [
    ./system
    ./common
    ./lib
    ./services
  ];
}