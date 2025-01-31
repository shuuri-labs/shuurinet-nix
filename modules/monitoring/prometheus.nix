{ config, lib, ... }:

let
  cfg = config.monitoring.prometheus;
in
{
  options.monitoring.prometheus = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the prometheus server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Port for the prometheus server";
    };

    exporters = {
      node = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 3002;
          description = "Port for the node exporter";
        };
      };
    };

    job_name = lib.mkOption {
      type = lib.types.str;
      default = "loggermon";
      description = "Job name for the prometheus server";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port cfg.exporters.node.port ];

    services.prometheus = {
      enable = true;
      port = cfg.port;

      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" "processes" ];
          port = cfg.exporters.node.port;
        };
      };

      scrapeConfigs = [
        {
          job_name = cfg.job_name;
          static_configs = [{
            targets = [ "127.0.0.1:${toString cfg.exporters.node.port}" ];
          }];
        }
      ];
    };
  };
}
