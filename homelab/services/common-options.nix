{ config, lib, pkgs, ... }:
let 
  homelab = config.homelab;
in
{
  options.homelab.services._.address = lib.mkOption {
    type = lib.types.str;
    default = "127.0.0.1";
    description = "Address to run the service on";
  };

  options.homelab.services._.port = lib.mkOption {
    type = lib.types.int;
    description = "Port to run the service on";
  };

  options.homelab.services._.domain = {
    enable = lib.mkEnableOption (builtins.concatStringsSep "" [
      "Enable “"
      name
      "” reverse‐proxy domain"
    ]);

    topLevel = lib.mkOption {
      type = lib.types.str;
      default = lib.mkDefault name;
      description = "Top‐level hostname (e.g. “${name}”) to be used for the reverse proxy.";
    };

    sub = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = homelab.domain.sub;
      description = "Subdomain (e.g. “www” or “app”) for service “${name}”, or null to omit.";
    };

    base = lib.mkOption {
      type = lib.types.str;
      default = homelab.domain.base;
      description = "Base domain (e.g. “${homelab.domain.base}”) for service “${name}”.";
    };

    final = lib.mkOption {
      type = lib.types.str;
      default = lib.mkDefault (
        let
          userSub      = config.homelab.services.${name}.domain.sub;
          userTopLevel = config.homelab.services.${name}.domain.topLevel;
          userBase     = config.homelab.services.${name}.domain.base;
        in
        if userSub != null then
          "${userTopLevel}.${userSub}.${userBase}"
        else
          "${userTopLevel}.${userBase}"
      );
      description = "Automatically‐computed FQDN for service “${name}” (e.g. “foo.bar.example.com”).";
    };

    serviceConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Configuration for the service";
    };
  };

  options.homelab.services._.homepage = {

  };
}
