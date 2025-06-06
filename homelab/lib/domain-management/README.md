# Unified Domain Module

This module provides a unified interface for managing domain that require both DNS records and reverse proxy configurations. Instead of manually configuring DNS and reverse proxy separately, you can define domain once and have both configurations generated automatically.

## Design

The module orchestrates the existing `homelab.dns` and `homelab.reverseProxy` modules by:

1. **Single Source of Truth**: Define a domain once with domain, backend, and configuration options
2. **Automatic Generation**: DNS records and reverse proxy hosts are generated from domain definitions
3. **Smart Defaults**: Falls back to `globalTargetIp` for DNS when no specific `targetIp` is set
4. **Flexible Configuration**: Can disable DNS or proxy per domain, add additional DNS records
5. **Type Safety**: Uses NixOS module system with proper types and validation

## Usage

```nix
{
  homelab.domains = {
    enable = true;
    
    domains = {
      mealie = {
        domain = "mealie.example.com";
        backend = {
          address = "192.168.1.100";
          port = 9925;
        };
        dns = {
          targetIp = "1.2.3.4";
          proxied = true;
        };
      };
      
      jellyfin = {
        domain = "jellyfin.example.com";
        backend = {
          port = 8096;  # address defaults to 127.0.0.1
        };
        dns = {
          # targetIp falls back to globalTargetIp
          additionalRecords = {
            "jf" = {
              name = "jf.example.com";
              content = "1.2.3.4";
            };
          };
        };
      };
      
      local-only-service = {
        domain = "internal.example.com";
        backend.port = 3000;
        dns.enable = false;  # Only create reverse proxy, no DNS
      };
    };
  };
}
```

## Generated Configuration

The above configuration automatically generates:

### DNS Records
```nix
homelab.dns.records = {
  mealie = {
    name = "mealie.example.com";
    type = "A";
    content = "1.2.3.4";
    proxied = true;
    ttl = 3600;
    comment = "Managed by NixOS homelab domains";
  };
  
  jellyfin = {
    name = "jellyfin.example.com";
    type = "A";
    content = config.homelab.dns.globalTargetIp;  # fallback
    proxied = false;
    ttl = 3600;
    comment = "Managed by NixOS homelab domains";
  };
  
  jellyfin-jf = {
    name = "jf.example.com";
    type = "A";
    content = "1.2.3.4";
    proxied = false;
    ttl = 3600;
    comment = "Additional record for jellyfin";
  };
};
```

### Reverse Proxy Hosts
```nix
homelab.reverseProxy.hosts = {
  mealie = {
    enable = true;
    domain = "mealie.example.com";
    backend = {
      address = "192.168.1.100";
      port = 9925;
    };
  };
  
  jellyfin = {
    enable = true;
    domain = "jellyfin.example.com";
    backend = {
      address = "127.0.0.1";
      port = 8096;
    };
  };
  
  local-only-service = {
    enable = true;
    domain = "internal.example.com";
    backend = {
      address = "127.0.0.1";
      port = 3000;
    };
  };
};
```

## Benefits

1. **Reduced Duplication**: No need to repeat domain names and domain details
2. **Consistency**: Ensures DNS and proxy configurations stay in sync
3. **Maintainability**: Single place to update domain configuration
4. **Type Safety**: NixOS module system provides validation and documentation
5. **Flexibility**: Can still disable individual components or add custom records

## Integration

The module automatically enables the required `homelab.dns` and `homelab.reverseProxy` modules when domains are defined, making it a drop-in solution for unified domain management. 