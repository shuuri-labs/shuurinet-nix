{ config, lib, ... }:
let
  cfg = config.monitoring.uptime-kuma;
in
{
  options.monitoring.uptime-kuma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the uptime-kuma server";
    };
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;
      settings = {
        PORT = "3009";
      };
    };

    networking.firewall.allowedTCPPorts = [ 3009 ];
  };
}
