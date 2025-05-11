{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.caddy;
  siteEnum = lib.types.enum [ "ldn" "bln" "tats" ];
in
{
  options.caddy = {
    enable = lib.mkEnableOption "caddy";

    environmentFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the environment file";
    };

    defaultSite = lib.mkOption {
      type = lib.types.nullOr siteEnum;
    };

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
          };

          baseUrl = lib.mkOption {
            type = lib.types.str;
            default = "shuuri.net";
          };

          site = lib.mkOption {
            type = lib.types.nullOr siteEnum;
            default = cfg.defaultSite;
          };

          destinationAddress = lib.mkOption {
            type = lib.types.str;
            default = "http://127.0.0.1";
          };

          destinationPort = lib.mkOption {
            type = lib.types.ints.between 0 65535;
          };

          tls = lib.mkOption {
            type = lib.types.str;
            default = "dns cloudflare {env.CF_API_KEY_TOKEN}";
          };
        };
      }));
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.caddy.serviceConfig = {
      EnvironmentFile = [
        cfg.environmentFile
      ];
    };

    networking.firewall.allowedTCPPorts = [ 443 ];

    services.caddy = {      
      enable = true;

      package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.1" ];
        hash = "sha256-saKJatiBZ4775IV2C5JLOmZ4BwHKFtRZan94aS5pO90=";
      };

      virtualHosts = lib.mkMerge (map (host: {
        "${host.name}${lib.optionalString (host.site != null) ".${host.site}"}.${host.baseUrl}" = {
          extraConfig = ''
            reverse_proxy ${host.destinationAddress}:${toString host.destinationPort}

            tls {
              ${host.tls}
            }
          '';
        };
      }) (lib.attrsets.mapAttrsToList (name: value: value) cfg.virtualHosts));
    };
  };
}