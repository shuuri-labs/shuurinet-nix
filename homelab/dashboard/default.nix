{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.dashboard;
  homelab = config.homelab;
  dashboardService = "homepage-dashboard";

  addProxy = import ../reverse-proxy/add-proxy.nix;
  
  # Combine glances widgets with network interface widgets
  allGlancesWidgets = cfg.glances.widgets // 
    (lib.listToAttrs (map (interface: {
      name = "Network ${interface}";
      value = {
        widget = {
          type = "glances";
          url = "${cfg.glances.address}:${toString cfg.glances.port}";
          metric = "network";
          interface = interface;
        };
      };
    }) cfg.glances.networkInterfaces));
in
{
  options.homelab.dashboard = {
    enable = lib.mkEnableOption "Enable dashboard";

    port = lib.mkOption {
      type = lib.types.int;
      default = 8082;
      description = "Port to run the dashboard on";
    };  

    sections = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "Sections to include in the dashboard";
      example = [
        {
          Monitoring = { style = "row"; columns = 2; };
        }
        {
          Media = { style = "row"; columns = 2; };
        }
      ];
    };

    glances = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address to run glances on";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 61208;
        description = "Port to run glances on";
      };

      networkInterfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Network interfaces to monitor";
      };

      widgets = lib.mkOption {
        type = lib.types.attrs;
        default = {
          CPU = {
            widget = {
              type = "glances";
              url = "${cfg.glances.address}:${toString cfg.glances.port}";
              metric = "cpu";
            };
          };

          Memory = {
            widget = {
              type = "glances";
              url = "${cfg.glances.address}:${toString cfg.glances.port}";
              metric = "memory";
            };
          };

          "Disk I/O" = {
            widget = {
              type = "glances";
              url = "${cfg.glances.address}:${toString cfg.glances.port}";
              metric = "disk";
              disk = "sda"
            };
          }
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.glances = {
      enable = true;
      port = cfg.glances.port;
    };

    services.${dashboardService} = {
      enable = true;
      port = cfg.port;
      
      settings = {
        title = "${config.networking.hostName} dashboard";
      };

      widgets = [ allGlancesWidgets ];
    };

    # addProxy {
    #   address = "127.0.0.1";
    #   port = cfg.port;
    #   domain = "${config.networking.hostName}.${homelab.domain.base}";
    # };
  };
}