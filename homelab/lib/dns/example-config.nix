# Example configuration showing how to use the DNS module
{
  homelab = {
    enable = true;
    
    # Enable DNS management
    dns = {
      enable = true;
      provider = "cloudflare";
      autoManage = true; # Automatically create DNS records for reverse proxy domains
      
      cloudflare = {
        enable = true;
        credentialsFile = "/etc/secrets/cloudflare-dns"; # Contains API credentials
        publicIp = "198.51.100.4"; # Your server's public IP
      };
      
      # Manual DNS records (optional)
      records = [
        {
          name = "api.example.com";
          type = "A";
          content = "198.51.100.5";
          proxied = false;
          comment = "API endpoint";
        }
      ];
    };
    
    # Enable reverse proxy
    reverseProxy.caddy.environmentFile = "/etc/secrets/caddy-cloudflare";
    
    # Enable services - DNS records will be created automatically!
    services = {
      mealie = {
        enable = true;
        domain.enable = true; # This will automatically create mealie.shuuri.net DNS record
      };
    };
  };
}

# The credentials file should contain:
# CLOUDFLARE_ZONE_ID=your_zone_id_here
# CLOUDFLARE_EMAIL=your_email@example.com  
# CLOUDFLARE_API_KEY=your_global_api_key_here 