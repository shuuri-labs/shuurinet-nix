{ config, lib, ... }:

let
  cfg = config.monitoring.grafana;
in

{
  options.monitoring.grafana = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "grafana.shuurinet-homelab";
    };
  };

  config = {
    services.grafana = {
      enable = true;

      addr = "0.0.0.0";
      domain = cfg.domain;

      provision = {
        datasources.settings = {
          apiVersion = 1;

          # Prometheus
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";  # direct access is not supported since Grafana 9.2.0
              url = "http://127.0.0.1:9090";  # adjust this to your Prometheus server URL
              isDefault = true;
              jsonData = {
                timeInterval = "15s";
                queryTimeout = "60s";
                httpMethod = "POST";
              };
            }
          ];
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 3000 ];
  };
}
