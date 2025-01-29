{ config, lib, ... }:

let
  cfg = config.monitoring.prometheus;
in
{
  options.monitoring.prometheus = {
    exporters = {
      node = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 9002;
          description = "Port for the node exporter";
        };
      };
    };
  };

  config = {
    services.prometheus = {
      enable = true;

      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = cfg.exporters.node.port;
        };
      };

      scrapeConfigs = [
        {
          job_name = "chrysalis";
          static_configs = [{
            targets = [ "127.0.0.1:${toString cfg.exporters.node.port}" ];
          }];
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [ 9090 9002 ];
  };
}