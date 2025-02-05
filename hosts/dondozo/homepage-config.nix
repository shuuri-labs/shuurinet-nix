{config, lib, ...}:

let
  hostCfgVars = config.host.vars;
in
{
  services.homepage-dashboard = {
    environmentFile = config.age.secrets.dondozo-homepage-vars.path;
    settings = {
      title = "dondozo dashboard";
      layout = [ 
        {
          Monitoring = { style = "row"; columns = 2; };
        }
        {
          Media = { style = "row"; columns = 2; };
        }
        {
          Downloads = { style = "row"; columns = 1; };
        }
        {
          Documents = { style = "row"; columns = 1; };
        }
      ];
      statusStyle = "dot";
    };
    widgets = [
      {
        resources = {
          cpu = true;
          disk = [ "/" hostCfgVars.storage.paths.bulkStorage hostCfgVars.storage.paths.fastStorage hostCfgVars.storage.paths.editingStorage ];
          memory = true;
          units = "metric";
          uptime = true;
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
    ];
    services = [
      {
        Media = [
          {
            Jellyfin = {
              icon = "jellyfin.png";
              href = "http://${hostCfgVars.network.config.hostAddress}:8096";
              siteMonitor = "http://${hostCfgVars.network.config.hostAddress}:8096";
              description = "Media Server";
              widget = {
                type = "jellyfin";
                url = "http://${hostCfgVars.network.config.hostAddress}:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
              };
            };
          }
          {
            Jellyseerr = {
              icon = "jellyseerr.png";
              href = "http://${hostCfgVars.network.config.hostAddress}:5055";
              siteMonitor = "http://${hostCfgVars.network.config.hostAddress}:5055";
              description = "Media Requests";
              widget = {
                type = "jellyseerr";
                url = "http://${hostCfgVars.network.config.hostAddress}:5055";
                key = "{{HOMEPAGE_VAR_JELLYSEERR_API_KEY}}";
              };
            };
          }
          {
            sonarr = {
              icon = "sonarr.png";
              href = "http://${hostCfgVars.network.config.hostAddress}:8989";
              description = "Media Management";
              siteMonitor = "http://${hostCfgVars.network.config.hostAddress}:8989";
              widget = {
                type = "sonarr";
                url = "http://${hostCfgVars.network.config.hostAddress}:8989";
                key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
              };
            };
          }
          {
            radarr = {
              icon = "radarr.png";
              href = "http://${hostCfgVars.network.config.hostAddress}:7878";
              description = "Media Management";
              siteMonitor = "http://${hostCfgVars.network.config.hostAddress}:7878";
              widget = {
                type = "radarr";
                url = "http://${hostCfgVars.network.config.hostAddress}:7878";
                key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
              };
            };
          }
        ];
      }
      {
        Downloads = [
          {
            Transmission = {
              icon = "transmission.png";
              href = "http://192.168.11.10:9091";
              siteMonitor = "http://192.168.15.1:9091";
              widget = {
                type = "transmission";
                url = "http://192.168.15.1:9091";
              };
            };
          }
        ];
      }
      {
        Monitoring = [
          {
            "Power Usage" = {
              icon = "home-assistant.png";
              href = "http://10.10.33.231";
              siteMonitor = "http://192.168.11.127:8123";
              widget = {
                type = "homeassistant";
                url = "http://192.168.11.127:8123";
                key = "{{HOMEPAGE_VAR_HOMEASSISTANT_API_KEY}}";
                custom = [
                  {
                    state = "sensor.server_plug_switch_0_power";
                    label = "Server Plug";
                  }
                ];
              };
            };
          }
          {
            Grafana = {
              icon = "grafana.png";
              href = "http://${hostCfgVars.network.config.hostAddress}:${toString config.monitoring.grafana.port}";
              siteMonitor = "http://${hostCfgVars.network.config.hostAddress}:${toString config.monitoring.grafana.port}";
              widget = {
                type = "grafana";
                url = "http://${hostCfgVars.network.config.hostAddress}:${toString config.monitoring.grafana.port}";
                username = "admin";
                # password = "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}"; # TODO: fix; don't forget to change environment variable
              };
            };
          }
        ];
      }
      {
        Documents = [
          {
            Paperless = {
              icon = "paperless.png";
              href = "http://${hostCfgVars.network.config.hostAddress}:28981";
              siteMonitor = "http://${hostCfgVars.network.config.hostAddress}:28981";
              description = "Document Management";
              widget = {
                type = "paperlessngx";
                url = "http://${hostCfgVars.network.config.hostAddress}:28981";
                key = "{{HOMEPAGE_VAR_PAPERLESS_API_KEY}}"; 
              };
            };
          }
        ];
      }
    ];
  };
}