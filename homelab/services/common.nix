# service-options.nix
{ lib, config, homelab, service }:
let
  domainLib = import ../lib/domain-management/compute.nix;

  domainTypes = import ../lib/domain-management/types.nix { inherit lib; };
  vpnConfinementTypes = import ../lib/vpn-confinement/types.nix { inherit lib; };
  idpTypes = import ../lib/idp/types.nix { inherit lib; };

  cfg = config.homelab.services.${service};
in
{
  options = {
    enable = lib.mkEnableOption (builtins.concatStringsSep "" [
      "Enable " service " service"
    ]);

    user = lib.mkOption {
      type = lib.types.str;
      default = service;
      description = "User to run the ${service} service as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = service;
      description = "Group to the ${service} user should be in";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Groups the ${service} user should be added to";
    };

    address = lib.mkOption {
      type        = lib.types.str;
      default     = "127.0.0.1";
      description = "Address to bind the ${service} service on";
    };

    port = lib.mkOption {
      type        = lib.types.int;
      description = "Port to run the ${service} service on";
    };

    fqdn = {
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
  };

  config = lib.mkMerge [
    {
      # Set the computed domain value
      homelab.services.${service}.fqdn.final = domainLib.computeDomain {
        topLevel = cfg.fqdn.topLevel;
        sub = cfg.fqdn.sub;
        base = cfg.fqdn.base;
      };
    }
    
    # Create domain configuration using the unified domain-management module
    (lib.mkIf cfg.enable {
      homelab.domainManagement.domains.${service} = {
        host = {
          domain = cfg.fqdn.final;
          backend = {
            address = cfg.address;
            port = cfg.port;
          };
        };
        dns = {
          comment = "Auto-managed by NixOS homelab for ${service}";
        };
      };

      homelab.idp.services.${service} = {
        name = service;
        originLanding = "https://${cfg.fqdn.final}";
      };

      homelab.vpnConfinement.services.${service} = {
        name = service;

        forwardPorts = {
          tcp = [ cfg.port ];
        };
      };
    })
  ];
}
