{ config, lib, pkgs, ... }:
let
  homelab = config.homelab;
  cfg      = homelab.lib.dashboard;

  dashboardService = "homepage-dashboard";
  domain = "${config.networking.hostName}.${homelab.domain.base}";
in
{
  imports = [
    ./glances.nix
  ];

  options.homelab.lib.dashboard = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable dashboard";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 8082;
      description = "Port to run the dashboard on";
    };

    categories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Monitoring" 
        "Media" 
        "Services"
      ];
      description = "Categories to include in the dashboard";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${dashboardService} = {
      enable = cfg.enable;
      listenPort = cfg.port;
      allowedHosts = domain;
      
      settings = {
        title = "${config.networking.hostName} dashboard";

        layout = [
          {
            Glances = lib.mkIf cfg.glances.enable {
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
          "Glances" = lib.mkIf cfg.glances.enable (
            lib.mapAttrsToList (name: config: {
              "${name}" = config;
            }) cfg.glances.widgets
          );
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
  };
}