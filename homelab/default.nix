{ lib, config, ... }:
let
  cfg = config.homelab;
in
{
  options.homelab = {
    enable = lib.mkEnableOption "homelab";

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
      base = lib.mkOption {
        type = lib.types.str;
        default = "shuuri.net";
        description = "Base domain name to be used to access the homelab services via Caddy reverse proxy";
      };

      sub = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Subdomain to be used to access the homelab services via Caddy reverse proxy";
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

    homelab.reverseProxy.caddy.environmentFile = "/etc/environment";
  };

  imports = [
    ./services
    # ./networks
    ./reverse-proxy
  ];
}