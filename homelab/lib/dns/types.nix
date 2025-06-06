{ lib }:
let
  inherit (lib) mkOption types;
in
{
  dnsRecordType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create this DNS record";
      };

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
        type = types.nullOr types.str;
        default = null;
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
} 