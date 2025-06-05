# Host options for reverse proxy and DNS management
{ lib }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  # Host configuration options that can be used by both proxy and DNS modules
  hostType = types.submodule {
    options = {
      # Proxy configuration
      proxy = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to create a reverse proxy for this host";
        };

        domain = mkOption {
          type = types.str;
          description = "Domain name for the reverse proxy";
        };

        backend = {
          address = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Backend server address";
          };

          port = mkOption {
            type = types.int;
            description = "Backend server port";
          };
        };

        # Additional proxy options
        tls = mkOption {
          type = types.str;
          default = "dns cloudflare {env.CF_API_KEY_TOKEN}";
          description = "TLS configuration for Caddy";
        };

        extraConfig = mkOption {
          type = types.str;
          default = "";
          description = "Additional Caddy configuration";
        };
      };

      # DNS configuration
      dns = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to create DNS records for this host";
        };

        targetIp = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Target IP for DNS record (falls back to global publicIp if null)";
        };

        type = mkOption {
          type = types.enum [ "A" "AAAA" "CNAME" ];
          default = "A";
          description = "DNS record type";
        };

        proxied = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to proxy traffic through Cloudflare";
        };

        ttl = mkOption {
          type = types.int;
          default = 3600;
          description = "Time to live in seconds";
        };

        comment = mkOption {
          type = types.str;
          default = "";
          description = "Comment for the DNS record";
        };
      };
    };
  };
} 