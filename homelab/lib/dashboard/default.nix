{ config, lib, pkgs, ... }:
let
  homelab = config.homelab;
  cfg = homelab.lib.dashboard;
  dashboardService = "homepage-dashboard";

  domainLib = import ../domain-management/compute.nix;

  domain = "${config.networking.hostName}.${homelab.domain.base}";
  
  # Combine glances widgets with network interface widgets
  allGlancesWidgets = cfg.glances.widgets // 
    (lib.listToAttrs (map (interface: {
      name = "Network ${interface}";
      value = {
        widget = {
          type = "glances";
          url = "http://${cfg.glances.address}:${toString cfg.glances.port}";
          metric = "network:${interface}";
          version = "4";
        };
      };
    }) cfg.glances.networkInterfaces));
in
{
  options.homelab.lib.dashboard = {
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
        default = "localhost";
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
              url = "http://${cfg.glances.address}:${toString cfg.glances.port}";
              metric = "cpu";
              version = "4";
            };
          };

          Memory = {
            widget = {
              type = "glances";
              url = "http://${cfg.glances.address}:${toString cfg.glances.port}";
              metric = "memory";
              version = "4";

            };
          };

          "Disk I/O" = {
            widget = {
              type = "glances";
              url = "http://${cfg.glances.address}:${toString cfg.glances.port}";
              metric = "disk:nvme0n1";
              version = "4";
            };
          };
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
      listenPort = cfg.port;
      allowedHosts = domain;
      
      settings = {
        title = "${config.networking.hostName} dashboard";

        layout = [
          {
            Glances = {
              header = false;
              style = "row";
              columns = 4;
            };
          }
        ];

        headerStyle = "clean";
        statusStyle = "dot";
        hideVersion = true;
        # background = "https://archives.bulbagarden.net/media/upload/b/b8/0977Dondozo.png";
        # todo - use tailwind to resize the background image. check 'Background Image' here:
        # https://gethomepage.dev/configs/settings/#description
      };

      customCSS = ''
        body, html {
          font-family: SF Pro Display, Helvetica, Arial, sans-serif !important;
        }
        .font-medium {
          font-weight: 700 !important;
        }
        .font-light {
          font-weight: 500 !important;
        }
        .font-thin {
          font-weight: 400 !important;
        }
        #information-widgets {
          padding-left: 1.5rem;
          padding-right: 1.5rem;
        }
        div#footer {
          display: none;
        }
        .services-group.basis-full.flex-1.px-1.-my-1 {
          padding-bottom: 3rem;
        };
      '';

      services = [
        {
          "Glances" = lib.mapAttrsToList (name: config: {
            "${name}" = config;
          }) allGlancesWidgets;
        }
      ];
    };

    homelab.lib.domainManagement.domains.${config.networking.hostName} = {
      enable = true;

      host = {
        enable = true;
        domain = domain;
        backend = {
          address = "localhost";
          port = cfg.port;
        };
      };

      dns = { 
        enable = true;
        comment = "Auto-managed by NixOS homelab for ${dashboardService}";
      };
    };

    # addProxy {
    #   address = "127.0.0.1";
    #   port = cfg.port;
    #   domain = "${config.networking.hostName}.${homelab.domain.base}";
    # };
  };
}