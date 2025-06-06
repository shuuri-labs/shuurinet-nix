{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.dns;
  inherit (lib) mkOption mkEnableOption types mkIf mkMerge;
  
  # DNS record type definition
  dnsRecordType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "DNS record name (e.g., 'mealie' or 'mealie.sub')";
      };
      
      type = mkOption {
        type = types.enum [ "A" "AAAA" "CNAME" ];
        default = "A";
        description = "DNS record type";
      };
      
      content = mkOption {
        type = types.str;
        description = "DNS record content (IP address or target)";
      };
      
      proxied = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to proxy traffic through Cloudflare";
      };
      
      ttl = mkOption {
        type = types.int;
        default = 3600;
        description = "Time to live in seconds";
      };
      
      comment = mkOption {
        type = types.str;
        default = "Managed by NixOS homelab";
        description = "Comment for the DNS record";
      };
    };
  };

in
{
  imports = [
    ./cloudflare.nix
  ];

  options.homelab.dns = {
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
    
    autoManage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically manage DNS records for reverse proxy domains";
    };
  };

  config = mkIf cfg.enable {
    # The actual implementation is delegated to provider-specific modules
    assertions = [
      {
        assertion = cfg.provider == "cloudflare" -> config.homelab.dns.cloudflare.enable;
        message = "Cloudflare DNS provider is selected but not configured";
      }
    ];
  };
} 