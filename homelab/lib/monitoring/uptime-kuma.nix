{ config, lib, ... }:
let
  cfg = config.homelab.lib.monitoring.uptime-kuma;
in
{
  options.homelab.lib.monitoring.uptimeKuma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the uptime-kuma server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3009;
      description = "Port for the uptime-kuma server";
    };
  };

  # config = lib.mkIf cfg.enable {
  #   services.uptime-kuma = {
  #     enable = true;
  #     settings = {
  #       PORT = "${toString cfg.port}";
  #     };
  #   };

  # };
}
