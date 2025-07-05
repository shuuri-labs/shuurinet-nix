{ config, ... }:
let
  domain = "pwr.${config.homelab.domain.fqdn}";
  smartPlugIp = "10.10.33.231";
  homeAssistantIp = "192.168.11.240";
  homeAssistantEntity = "sensor.server_plug_switch_0_power";
in
{
  config = {
    homelab = { 
      lib = {
        # domainManagement.domains.power = {
        #   enable = true;

        #   host = {
        #     enable = true;
        #     domain = domain;
        #     backend = {
        #       address = "http://10.10.33.231";
        #       port = 80;
        #     };
        #   };

        #   dns = { 
        #     enable = true;
        #   };
        # };

        dashboard.entries.power = {
          icon = "home-assistant.png";
          href = "http://${smartPlugIp}";
          siteMonitor = "http://${smartPlugIp}";
          description = "System Power";
          section = "Monitoring";
          widget = {
            type =  "homeassistant";
            url = "http://${homeAssistantIp}:8123";
            key = "{{HOMEPAGE_VAR_HOMEASSISTANT_API_KEY}}";
            custom = [
              {
                state = homeAssistantEntity;
                label = "Server Plug";
              }
            ];
          };
        };
      };
    };
  };
}