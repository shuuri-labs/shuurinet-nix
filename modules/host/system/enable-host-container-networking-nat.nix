{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption;
  cfg = config.hypervisor.ct.networkingNat;
in 
{
  options.hypervisor.ct.networkingNat = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NAT for containers";
    };

    interfaceExternal = mkOption {
      type = lib.types.str;
      default = "br0";
      description = "External interface for NAT";
    };
  };
  
  config = lib.mkIf cfg.enable {
    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = cfg.interfaceExternal;
    };

    # IPv6 forwarding
    boot.kernel.sysctl = {
      "net.ipv6.conf.all.forwarding" = true;
      "net.ipv4.ip_forward" = true;
    };
  };
}