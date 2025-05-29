{config, ...}:
{
  services.homepage-dashboard = {
    environmentFile = config.age.secrets.homepage-vars.path;
    settings = {
      title = "${config.networking.hostName} dashboard";
      layout = [ 
        {
          Monitoring = { style = "row"; columns = 2; };
        }
        {
          Services = { style = "row"; columns = 2; };
        }
      ];
      statusStyle = "dot";
    };
    widgets = [
      {
        resources = {
          cpu = true;
          disk = [ "/" ];
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
        Monitoring = [
          {
            "Power Usage" = {
              icon = "home-assistant.png";
              href = "http://10.10.33.181";
              siteMonitor = "http://192.168.11.240:8123";
              widget = {
                type = "homeassistant";
                url = "http://192.168.11.240:8123";
                key = "{{HOMEPAGE_VAR_HOMEASSISTANT_API_KEY}}";
                custom = [
                  {
                    state = "sensor.router_plug_switch_0_power";
                    label = "Router Plug";
                  }
                ];
              };
            };
          }

        ];
      }
      {
        Services = [
          {
            "Home Assistant" = {
              icon = "home-assistant.png";
              href = "http://192.168.11.240:8123";
              siteMonitor = "http://192.168.11.240:8123";
              widget = {
                type = "homeassistant";
                url = "http://192.168.11.240:8123";
                key = "{{HOMEPAGE_VAR_HOMEASSISTANT_API_KEY}}";
              };
            };
          }
          {
            "OpenWRT" = {
              icon = "openwrt.png";
              href = "http://192.168.11.1";
              siteMonitor = "http://192.168.11.1";
              widget = {
                type = "openwrt";
                url = "http://192.168.11.1";
                username = "{{HOMEPAGE_VAR_OPENWRT_USERNAME}}";
                password = "{{HOMEPAGE_VAR_OPENWRT_PASSWORD}}";
              };
            };
          }
        ];
      }
    ];
  };
}