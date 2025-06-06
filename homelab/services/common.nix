# service-options.nix
{ lib, config, homelab, service }:
let
  domainLib = import ../lib/domain/compute.nix;
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

      description = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault service;
        description = "Description of the service for the dashboard.";
      };

      icon = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault "default";
        description = "Icon to use for the service on the dashboard.";
      };

      href = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault "https://${config.homelab.services.${service}.domain.final}";
        description = "URL for the service on the dashboard.";
      };
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
    
    # Create host configuration directly
    # see reverse-proxy/host-options.nix for more details on type
    (lib.mkIf cfg.enable {
      homelab.reverseProxy.hosts.${service} = {
        proxy = {
          enable = cfg.domain.enable;
          domain = cfg.domain.final;
          backend = {
            address = cfg.address;
            port = cfg.port;
          };
        };
      };
      
      # Create DNS record directly in the DNS module
      homelab.dns.records.${service} = lib.mkIf cfg.domain.enable {
        name = cfg.domain.final;
        type = "A";
        content = homelab.dns.globalTargetIp;
        proxied = false;
        ttl = 3600;
        comment = "Auto-managed by homelab for ${service}";
      };
    })
  ];
}
