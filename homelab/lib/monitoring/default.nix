{ config, lib, ... }:
let
  cfg = config.homelab.lib.monitoring;
in
{
  imports = [
    ./prometheus.nix
    ./grafana.nix
    ./loki.nix
    ./uptime-kuma.nix
  ];

  options.homelab.lib.monitoring = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the monitoring module";
    };
  };

  config = lib.mkIf cfg.enable {
    homelab.lib.monitoring.prometheus.enable = true;
    homelab.lib.monitoring.grafana.enable = true;
    homelab.lib.monitoring.loki.enable = true;
    # homelab.monitoring.uptime-kuma.enable = true;
  };
}
