{ config, lib, ... }:
let
  cfg = config.monitoring;
in
{
  imports = [
    ./prometheus.nix
    ./grafana.nix
    ./loki.nix
    ./uptime-kuma.nix
  ];

  options.monitoring = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the monitoring module";
    };
  };

  config = lib.mkIf cfg.enable {
    monitoring.prometheus.enable = true;
    monitoring.grafana.enable = true;
    monitoring.loki.enable = true;
    monitoring.uptime-kuma.enable = true;
  };
}
