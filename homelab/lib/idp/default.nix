{ config, lib, pkgs, ... }:
let 
  cfg = config.homelab.idp;
  homelab = config.homelab;

  domainLib = import ../domain-management/compute.nix;
  idpTypes = import ./types.nix { inherit lib; };
in
{
  imports = [
    ./kanidm.nix
  ];

  options.homelab.idp = {
    enable = lib.mkEnableOption "idp";

    provider = lib.mkOption {
      type = lib.types.str;
      description = "The IDP provider to use";
    };

    port = lib.mkOption {
      type = lib.types.int;
      description = "Port for the IDP service";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "https://127.0.0.1";
      description = "Address for the IDP service";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = domainLib.computeDomain { topLevel = "auth"; sub = homelab.domain.sub; base = homelab.domain.base; };
      description = "Base domain name for auth";
    };

    oidcConfigurationUrl = lib.mkOption {
      type = lib.types.str;
      description = "OIDC configuration URL for the IDP service";
    };
    
    users = lib.mkOption {
      type = lib.types.attrsOf idpTypes.userType;
      description = "Users to add to the IDP service";
      default = {
        "ashley" = {
          enable = true;
          name = "Ashley";
          email = "ashley@shuuri.net";
        };
      };
    };

    services = lib.mkOption {
      type = lib.types.attrsOf idpTypes.serviceType;
      description = "Services to add to the IDP service";
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    homelab.domainManagement.domains.auth = {
      enable = true;

      host = {
        enable = true;
        domain = cfg.domain;
        backend = {
          address = cfg.address;
          port = cfg.port;
        };
      };

      dns = { 
        enable = true;
        comment = "Auto-managed by NixOS homelab for auth";
      };
    };
  };
}