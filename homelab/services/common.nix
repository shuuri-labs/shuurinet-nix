# service-options.nix
{ lib, config, homelab, service }:
let
  domainLib = import ../lib/domain.nix;
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

    homepage = {
      enable = lib.mkEnableOption (builtins.concatStringsSep "" [
        "Enable " service " homepage entry"
      ]);

      description = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault service;
        description = "Description of the service for the homepage.";
      };

      icon = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault "default";
        description = "Icon to use for the service on the homepage.";
      };

      href = lib.mkOption {
        type    = lib.types.str;
        default = lib.mkDefault "https://${config.homelab.services.${service}.domain.final}";
        description = "URL for the service on the homepage.";
      };
    };
  };

  config = {
    # Set the computed domain value
    homelab.services.${service}.domain.final = domainLib.computeDomain {
      topLevel = cfg.domain.topLevel;
      sub = cfg.domain.sub;
      base = cfg.domain.base;
    };
  };
}
