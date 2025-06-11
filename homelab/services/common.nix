# service-options.nix
{ lib, config, homelab, service }:
let
  domainLib = import ../lib/domain-management/compute.nix;
  vpnConfinementTypes = import ../lib/vpn-confinement/types.nix { inherit lib; };

  cfg = config.homelab.services.${service};
in
{
  options = {
    enable = lib.mkEnableOption (builtins.concatStringsSep "" [
      "Enable " service " service"
    ]);

    address = lib.mkOption {
      type        = lib.types.str;
      default     = "127.0.0.1";
      description = "Address to bind the ${service} service on";
    };

    port = lib.mkOption {
      type        = lib.types.int;
      description = "Port to run the ${service} service on";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = service;
      description = "User to run the ${service} service as";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Group the ${service} user should be added to";
    };

    domain = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = builtins.concatStringsSep "" [
          "Enable " service " reverse-proxy domain"
        ];
      };

      topLevel = lib.mkOption {
        type    = lib.types.str;
        default = service;
        description = "Top-level hostname (e.g. ${service}) to be used for the reverse proxy.";
      };

      sub = lib.mkOption {
        type        = lib.types.nullOr lib.types.str;
        default     = homelab.domain.sub;
        description = builtins.concatStringsSep "" [
          "Subdomain (e.g. \"www\" or \"app\") for service "
          service
          ", or null to omit."
        ];
      };

      base = lib.mkOption {
        type    = lib.types.str;
        default = homelab.domain.base;
        description = builtins.concatStringsSep "" [
          "Base domain (e.g. "
          homelab.domain.base
          ") for service "
          service
          "."
        ];
      };

      final = lib.mkOption {
        type = lib.types.str;
        description = builtins.concatStringsSep "" [
          "Automatically-computed FQDN for service " service ""
        ];
      };
    };

    dashboard = {
      enable = lib.mkEnableOption (builtins.concatStringsSep "" [
        "Enable " service " dashboard entry"
      ]);

      icon = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault "${service}.png";
        description = "Icon to use for the service on the dashboard.";
      };

      description = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault "";
        description = "Description of the service for the dashboard.";
      };

      href = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault "https://${config.homelab.services.${service}.domain.final}";
        description = "URL for the service on the dashboard.";
      };

      siteMonitor = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault "https://${config.homelab.services.${service}.domain.final}:${toString config.homelab.services.${service}.port}";
        description = "URL to monitor the service on the dashboard.";
      };

      widget = lib.mkOption {
        type    = lib.types.attrs;
        default = lib.mkDefault {};
        description = "Widget to use for the service on the dashboard.";
      };
    };

    vpnConfinement = lib.mkOption {
      type = vpnConfinementTypes.serviceType;
      default = {
        enable = false;
        forwardPorts = {
          tcp = [ cfg.port ];
        };
      };
      description = "VPN confinement configuration for the service";
    }; 
  };

  config = lib.mkMerge [
    {
      # Set the computed domain value
      homelab.services.${service}.domain.final = domainLib.computeDomain {
        topLevel = cfg.domain.topLevel;
        sub = cfg.domain.sub;
        base = cfg.domain.base;
      };
    }
    
    # Create domain configuration using the unified domain-management module
    (lib.mkIf cfg.enable {
      homelab.domainManagement.domains.${service} = {
        enable = cfg.domain.enable;
        host = {
          enable = cfg.domain.enable;
          domain = cfg.domain.final;
          backend = {
            address = cfg.address;
            port = cfg.port;
          };
        };
        dns = {
          enable = cfg.domain.enable;
          comment = "Auto-managed by NixOS homelab for ${service}";
        };
      };

      homelab.vpnConfinement = { 
        services.${service} = cfg.vpnConfinement // {
          enable = cfg.vpnConfinement.enable;
        };
      };
    })
  ];
}
