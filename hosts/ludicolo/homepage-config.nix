{config, lib, ...}:

let
  hostCfgVars = config.host.vars;
in
{
  services.homepage-dashboard = {
    environmentFile = config.age.secrets.ludicolo-homepage-vars.path;
    settings = {
      title = "${hostCfgVars.network.config.hostName} dashboard";
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
              href = "http://10.11.20.10:9091";
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
    ];
  };
}