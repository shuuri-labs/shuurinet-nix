# Template for creating new homelab services
# Copy this file and replace:
# - "SERVICE_NAME" with  service name (e.g. "jellyfin", "nextcloud")
# - PORT_NUMBER with the default port for your service
# - Add any service-specific options as needed

{ config, lib, pkgs, ... }:
let
  service = "SERVICE_NAME";  # Replace with your service name
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  domainLib = import ../../lib/domain.nix;

  # Import the common options (includes domain computation via domain.nix)
  homelabServiceCommon = import ../common.nix {
    inherit lib config homelab service;
  };
in
{
  options.homelab.services.${service} = homelabServiceCommon.options // {
    # Override port to provide a default for this service
    port = lib.mkOption {
      type = lib.types.int;
      default = PORT_NUMBER;  # Replace with your service's default port
      description = "Port to run the ${service} service on";
    };
    
    # Add service-specific options here
    # Example:
    # dataPath = lib.mkOption {
    #   type = lib.types.str;
    #   default = "/var/lib/${service}";
    #   description = "Path to store ${service} data";
    # };
  };

  config = lib.mkMerge [
    # Include the common config (domain computation)
    homelabServiceCommon.config
    
    (lib.mkIf cfg.enable {
      services.${service} = {
        enable = true;
        port = cfg.port;
        # Add other NixOS service options as needed
      };
      
      # Example: Override or extend the host configuration created by common.nix
      # This will merge with the configuration automatically created in common.nix
      # homelab.reverseProxy.hosts.${service} = {
      #   proxy = {
      #     # The common config creates basic proxy settings, you can override:
      #     # extraConfig = ''
      #     #   # Custom Caddy directives for this service
      #     #   header / {
      #     #     X-Custom-Header "value"
      #     #   }
      #     # '';
      #   };
      #   dns = {
      #     # Override DNS settings:
      #     # targetIp = "10.0.0.100";  # Custom IP for this service
      #     # ttl = 300;                # Custom TTL
      #     # type = "CNAME";           # Use CNAME instead of A record
      #     # proxied = false;          # Disable Cloudflare proxy
      #   };
      # };
    })
  ];
} 