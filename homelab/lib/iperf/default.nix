{ config, pkgs, lib, ... }:
{
  options.homelab.lib.iperf = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable iperf3 service";
    };
  };

  config = lib.mkIf config.homelab.lib.iperf.enable {
    services.iperf3 = {
      enable = true;
      openFirewall = true;
    };

    environment.systemPackages = with pkgs; [
      iperf3
    ];
  };
}
