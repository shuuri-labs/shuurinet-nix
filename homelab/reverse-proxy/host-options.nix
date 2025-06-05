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
    };
  };
} 