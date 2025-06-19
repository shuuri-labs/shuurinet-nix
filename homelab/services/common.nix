# service-options.nix
{ lib, config, homelab, service }:
let
  cfg = homelab.services.${service};

  domainLib = import ../lib/domain-management/compute.nix;
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
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable dashboard entry for ${service}";
      };
    };

    idp = {
      enable = lib.mkEnableOption (builtins.concatStringsSep "" [
        "Enable " service " IDP"
      ]);
    };
  };

  config = lib.mkIf cfg.enable {
    homelab = {
      services.${service}.fqdn.final = domainLib.computeFQDN {
        topLevel = cfg.fqdn.topLevel;
        sub = cfg.fqdn.sub;
        base = cfg.fqdn.base;
      };

      lib = { 
        domainManagement.domains.${service} = {
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

        dashboard.entries.${service} = {
          enable = cfg.dashboard.enable;
          section = lib.mkDefault "Services";
          icon = lib.mkDefault "${service}.png";
          href = lib.mkDefault "https://${homelab.services.${service}.fqdn.final}";
          siteMonitor = lib.mkDefault "https://${homelab.services.${service}.fqdn.final}";
        };

        idp.services.inputs.${service} = {
          name = service;
          originLanding = "https://${cfg.fqdn.final}";
        };

        vpnConfinement.services.${service} = {
          name = service;

          forwardPorts = {
            tcp = [ cfg.port ];
          };
        };
      };
    };
  };
}
