{ lib, config, pkgs, ... }:
let
  cfg = config.homelab;

  hostDomain = "${config.networking.hostName}.${cfg.domain.base}";
in
{
  options.homelab = {
    enable = lib.mkEnableOption "Enable homelab";

    system = {
      isPhysical = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the system is physical or a VM";
      };

      timeZone = lib.mkOption {
        default = "Europe/Berlin";
        type = lib.types.str;
        description = ''
          Time zone to be used for the homelab services
        '';
      };
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
    };
  };

  config = lib.mkIf cfg.enable {
    # boot.kernelParams = lib.mkIf cfg.systewm.isPhysical [
    #   "pcie_aspm=force"
    #   "pcie_aspm.policy=powersave"
    # ]; 

    # time.timeZone = cfg.system.timeZone;

    # swapDevices = [{
    #   device = "/swapfile";
    #   size = 16 * 1024; # 16GB
    # }];

    # homelab.reverseProxy.caddy.environmentFile = "/etc/environment";

    homelab = {
      # dashboard = {
      #   enable = true;
      #   glances.networkInterfaces = [ "enp3s0" ];
      # };

      reverseProxy = {
        enable = true;
      };

      dns = {
        enable = true;

        cloudflare = {
          enable = true;
          publicIp = cfg.networking.primaryBridge.address;
        };
      };
    };
  };

  imports = [
    ./network
    # ./dashboard
    ./reverse-proxy
    ./dns
    ./services
  ];
}