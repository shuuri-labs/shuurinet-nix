{ config, pkgs, lib, ... }:

let
  cfg = config.remoteAccess.ddns;
in 
{
  options.remoteAccess.ddns = {
    enable = lib.mkEnableOption "ddns";

      tokenFile = lib.mkOption {
        type = lib.types.str;
        description = "The path to the file containing the Cloudflare API token";
      };

      zone = lib.mkOption {
        type = lib.types.str;
        description = "The root zone to update";
        example = "example.com";
      };

      zoneId = lib.mkOption {
        type = lib.types.str;
        description = "The Cloudflare Zone ID";
      };

      domains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "The domains to update";
        example = [ "home.example.com" ];
      };

      usev4 = lib.mkOption {
        type = lib.types.str;
        description = "The method to detect your current IPv4";
        default = "webv4, webv4=ipv4.ident.me/";
      };

      usev6 = lib.mkOption {
        type = lib.types.str;
        description = "The method to detect your current IPv6";
        default = "";
      };
    };
  

  config = lib.mkIf cfg.enable {
    services.ddclient = {
      enable       = true;                # turn it on
      package      = pkgs.ddclient;       # which ddclient to run
      interval     = "5m";                # every 5 minutes :contentReference[oaicite:4]{index=4}
      protocol     = "cloudflare";        # use Cloudflare's API :contentReference[oaicite:5]{index=5}
      server       = "api.cloudflare.com/client/v4";
      ssl          = true;

      username     = "token";             # literal "token" for API-Token auth
      passwordFile = cfg.tokenFile;

      zone         = cfg.zone;
      # zoneId       = cfg.zoneId;
      domains      = cfg.domains;

      usev4        = cfg.usev4;
      usev6        = cfg.usev6;
      quiet        = false;
      verbose      = false;
    };
  };
}
