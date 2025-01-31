{config, lib, ... }:

let
  cfg = config.monitoring.loki;
in
{
  options.monitoring.loki = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the loki server";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 3005;
    };

    promtail.port = lib.mkOption {
      type = lib.types.int;
      default = 3006;
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "host";
    };
  };

  config = lib.mkIf cfg.enable {
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;

        server = {
          http_listen_port = cfg.port;
        };

        ingester = {
          lifecycler = {
            address = "0.0.0.0";
            ring = {
              kvstore.store = "inmemory";
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          chunk_idle_period = "1h";
          max_chunk_age = "1h";
          chunk_target_size = 1048576;
          chunk_retain_period = "30s";
        };

        schema_config.configs = [{
          from = "2025-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];

        storage_config = {
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/boltdb-shipper-active";
            cache_location = "/var/lib/loki/boltdb-shipper-cache";
            cache_ttl = "24h";
          };
          filesystem.directory = "/var/lib/loki/chunks";
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };

        compactor = {
          working_directory = "/var/lib/loki";
          compactor_ring = {
            kvstore = {
              store = "inmemory";
            };
          };
        };
      };
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = cfg.promtail.port;
          grpc_listen_port = 0;
        };

        positions = {
          filename = "/tmp/positions.yaml";
        };

        clients = [
          {
            url = "http://127.0.0.1:${toString cfg.port}/loki/api/v1/push";
          }
        ];

        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = cfg.hostname;
              };
            };

            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };
  };
}