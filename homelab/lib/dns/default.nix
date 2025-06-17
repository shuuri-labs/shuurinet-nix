{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.lib.dns;
  inherit (lib) mkOption mkEnableOption types mkIf mkMerge;
  inherit (import ./types.nix { inherit lib; }) dnsRecordType;
in
{
  imports = [
    ./cloudflare.nix
  ];

  options.homelab.lib.dns = {
    enable = mkEnableOption "DNS management";
    
    provider = mkOption {
      type = types.enum [ "cloudflare" ];
      default = "cloudflare";
      description = "DNS provider to use";
    };
    
    globalTargetIp = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Global target IP address to use as fallback for DNS records when no specific targetIp is set";
    };
    
    records = mkOption {
      type = types.attrsOf dnsRecordType;
      default = {};
      description = "DNS records to manage, organized by service/record name";
      example = {
        mealie = {
          name = "mealie.example.com";
          type = "A";
          content = "192.168.1.100";
          proxied = true;
          ttl = 3600;
          comment = "Mealie service";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # The actual implementation is delegated to provider-specific modules
    assertions = [
      {
        assertion = cfg.provider == "cloudflare" -> cfg.cloudflare.enable;
        message = "Cloudflare DNS provider is selected but not configured";
      }
    ];
  };
} 