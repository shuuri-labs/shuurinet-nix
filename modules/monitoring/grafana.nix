{ config, lib, pkgs,... }:

let
  cfg = config.monitoring.grafana;
in

{
  options.monitoring.grafana = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the grafana server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for the grafana server";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "grafana.shuurinet-homelab";
    };

    lokiUid = lib.mkOption {
      type = lib.types.str;
      default = "P8E80F9AEF21F6940";
      description = ''
        UID of loki instance. Setting here as it's required by 
        any dashboard that uses loki as a datasource.
        TODO: Make this dynamic in loki-dependent dashboard json files.
      '';
    };

    adminPassword = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Password for the grafana admin user. Change in prodution!";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ]; 

    services.grafana = {
      enable = true;

      settings = {
        security.admin_password = cfg.adminPassword;

        server = {
          http_addr = "0.0.0.0";
          http_port = cfg.port;
          domain = cfg.domain;
        };
      };

      provision = {
        datasources.settings = {
          apiVersion = 1;

          # Prometheus
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy"; 
              url = "http://127.0.0.1:${toString config.monitoring.prometheus.port}";
              isDefault = true;
              jsonData = {
                timeInterval = "15s";
                queryTimeout = "60s";
                httpMethod = "POST";
              };
            }
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:${toString config.monitoring.loki.port}";
              uid = cfg.lokiUid;
            }
          ];
        };

        dashboards.settings = {
          providers = [
            {
              options.path = ./grafana-dashboards;
            }
          ];
        };
      };
    };
  };
}
