{ config, lib, pkgs, ... }:
let
  service = "mealie";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options // {
    port = lib.mkOption {
      type = lib.types.int;
      default = 9001;
      description = "Port to run the ${service} service on";
    };
  };

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      services.${service} = {
        enable = true;
        port = cfg.port;
      };
      
      # Example: Override the host configuration created by common.nix
      # This demonstrates how you can customize proxy/DNS settings per service
      # homelab.reverseProxy.hosts.${service} = {
      #   proxy = {
      #     # Add custom Caddy configuration for mealie
      #     extraConfig = ''
      #       # Increase client max body size for recipe imports
      #       request_body {
      #         max_size 50MB
      #       }
      #       
      #       # Custom headers for mealie
      #       header {
      #         X-Frame-Options "SAMEORIGIN"
      #         X-Content-Type-Options "nosniff"
      #       }
      #     '';
      #   };
      #   dns = {
      #     # Example: Use a different IP for mealie (e.g., if running on a VM)
      #     # targetIp = "10.0.0.150";
      #     # ttl = 300;
      #   };
      # };
    })
  ];
}