{config, hostMainIp, ... }:

let
  hostCfgVars = config.host.vars;
in
{
  services.homepage-dashboard = {
    environmentFile = config.age.secrets.ludicolo-homepage-vars.path;
    settings = {
      title = "${hostCfgVars.network.hostName} dashboard";
      layout = [ 
        {
          Monitoring = { style = "row"; columns = 2; };
        }
        {
          "Home & Security" = { style = "row"; columns = 2; };
        }
        {
          Media = { style = "row"; columns = 2; };
        }
        {
          Downloads = { style = "row"; columns = 1; };
        }
      ];
      statusStyle = "dot";
    };
    widgets = [
      {
        resources = {
          cpu = true;
          disk = [ "/" hostCfgVars.storage.paths.bulkStorage ];
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
        "Home & Security" = [
          {
            "Home Assistant" = {
              icon = "home-assistant.png";
              href = "http://${hostMainIp}:8123";
              widget = {
                type = "homeassistant";
                url = "http://${hostMainIp}:8123";
                key = "{{HOMEPAGE_VAR_HOME_ASSISTANT_API_KEY}}";
              };
            };
          }
          {
            "Frigate" = {
              icon = "frigate.png";
              href = "https://frigate.ldn.shuuri.net";
              siteMonitor = "http://127.0.0.1:5001";
              description = "Home Security";
              widget = {
                type = "frigate";
                url = "http://127.0.0.1:5001";
                enableRecentEvents = true;
              };
            };
          }
        ];
      }
      {
        Media = [
          {
            Jellyfin = {
              icon = "jellyfin.png";
              href = "https://jellyfin.ldn.shuuri.net";
              siteMonitor = "http://127.0.0.1:8096";
              description = "Media Server";
              widget = {
                type = "jellyfin";
                url = "http://127.0.0.1:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
              };
            };
          }
          {
            Jellyseerr = {
              icon = "jellyseerr.png";
              href = "https://requests.ldn.shuuri.net";
              siteMonitor = "http://127.0.0.1:5055";
              description = "Media Requests";
              widget = {
                type = "jellyseerr";
                url = "http://127.0.0.1:5055";
                key = "{{HOMEPAGE_VAR_JELLYSEERR_API_KEY}}";
              };
            };
          }
          {
            sonarr = {
              icon = "sonarr.png";
              href = "https://sonarr.ldn.shuuri.net";
              description = "Media Management";
              siteMonitor = "http://127.0.0.1:8989";
              widget = {
                type = "sonarr";
                url = "http://127.0.0.1:8989";
                key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
              };
            };
          }
          {
            radarr = {
              icon = "radarr.png";
              href = "https://radarr.ldn.shuuri.net";
              description = "Media Management";
              siteMonitor = "http://127.0.0.1:7878";
              widget = {
                type = "radarr";
                url = "http://127.0.0.1:7878";
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
              href = "https://transmission.ldn.shuuri.net";
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
            Grafana = {
              icon = "grafana.png";
              href = "https://grafana.ldn.shuuri.net";
              siteMonitor = "http://127.0.0.1:${toString config.monitoring.grafana.port}";
              widget = {
                type = "grafana";
                url = "http://127.0.0.1:${toString config.monitoring.grafana.port}";
                username = "admin";
                # password = "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}"; # TODO: fix; don't forget to change environment variable
              };
            };
          }
        ];
      }
    ];
  };
}