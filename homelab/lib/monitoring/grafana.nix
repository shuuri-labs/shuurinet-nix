{ config, lib, pkgs,... }:

let
  monitoring = config.homelab.lib.monitoring;
  cfg = monitoring.grafana;
  domainLib = import ../domain-management/compute.nix;
in

{
  options.homelab.lib.monitoring.grafana = {
    enable = lib.mkEnableOption "grafana";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for the grafana server";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = domainLib.computeFQDN {
        topLevel = "grafana";
        sub = config.homelab.domain.sub;
        base = config.homelab.domain.base;
      };
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
    homelab.lib.domainManagement.domains.grafana = {
      enable = true;

      host = {
        enable = true;
        domain = cfg.domain;
        backend = {
          address = "localhost";
          port = cfg.port;
        };
      };

      dns = { 
        enable = true;
        comment = "Auto-managed by NixOS homelab for grafana";
      };
    };


    services.grafana = {
      enable = true;

      settings = {
        security.admin_password = cfg.adminPassword;

        server = {
          http_addr = "127.0.0.1";
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
              url = "http://127.0.0.1:${toString monitoring.prometheus.port}";
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
              url = "http://127.0.0.1:${toString monitoring.loki.port}";
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
