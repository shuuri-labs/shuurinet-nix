{ config, ... }:
let
  cfg = config.monitoring.uptime-kuma;
in
{
  options.monitoring.uptime-kuma = {

  };

  config = {
    services.uptime-kuma = {
      enable = true;
      settings = {
        PORT = "3001";
      };
    };

    networking.firewall.allowedTCPPorts = [ 3001 ];
  };
}
