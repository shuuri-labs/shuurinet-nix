{ config, lib, pkgs, ... }:
let 
  homelab = config.homelab;
  cfg = homelab.lib.idp;
  
  idpTypes = import ./types.nix { inherit lib; };
in
{
  imports = [
    ./kanidm.nix
  ];

  options.homelab.lib.idp = {
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
      default = "auth.${homelab.domain.base}";
      description = "Base domain name for auth";
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

    services = {
      inputs = lib.mkOption {
        type = lib.types.attrsOf idpTypes.serviceType;
        description = "Services to add to the IDP service (inputs)";
        default = {};
      };

      outputs = lib.mkOption {
        type = lib.types.attrsOf idpTypes.serviceType;
        description = "Computed complete services with oidc defaults set by the IDP implementation";
        default = {};
      };
    };
  };

  config = lib.mkIf cfg.enable {
    homelab.lib.domainManagement.domains.auth = {
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