{ config, lib, pkgs, ... }:
let 
  cfg = config.homelab.idp;
  homelab = config.homelab;

  domainLib = import ../lib/utils/domain-management/compute.nix;
  idpTypes = import ./types.nix { inherit lib; };
in
{
  imports = [
    ./kanidm.nix
  ];

  options.homelab.idp = {
    enable = lib.mkEnableOption "idp";

    port = lib.mkOption {
      type = lib.types.int;
      description = "Port for the IDP service";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = domainLib.computeDomain { topLevel = "auth"; sub = homelab.domain.sub; base = homelab.domain.topLevel; };
      description = "Base domain name for auth";
    };
    
    users = lib.mkOption {
      type = lib.types.attrsOf idpTypes.userType;
      description = "Users to add to the IDP service";
      default = {
        "ashley" = {
        };
      };
    };

    services = lib.mkOption {
      type = lib.types.attrsOf idpTypes.serviceType;
      description = "Services to add to the IDP service";
      default = {
        "kanidm" = {
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    homelab.domainManagement.domains.auth = {
      enable = true;

      host = {
        enable = true;
        domain = cfg.domain;
        backend = {
          address = "localhost";
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