{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.domainManagement;
  
  inherit (lib) mkOption mkEnableOption types mkIf mkMerge mapAttrs' nameValuePair filterAttrs;
  inherit (import ../dns/types.nix { inherit lib; }) dnsRecordType;
  inherit (import ../reverse-proxy/types.nix { inherit lib; }) hostType;
  
  # Domain definition type that combines DNS and reverse proxy configuration
  domainType = types.submodule ({ name, config, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable reverse proxy and DNS records for this domain";
      };

      host = mkOption {
        type = hostType;
        description = "Host configuration for the domain";
      };

      dns = mkOption {
        type = dnsRecordType;
        description = "DNS configuration for the domain";
      };
    };
  });

in
{
  options.homelab.domainManagement = {
    enable = mkEnableOption "Unified domain management (DNS + Reverse Proxy)";
    
    domains = mkOption {
      type = types.attrsOf domainType;
      default = {};
      description = "Domains to manage with unified DNS and reverse proxy configuration";
      example = {
        mealie = {
          host = {
            enable = true;
            domain = "mealie.example.com";
          };
          dns = {
            targetIp = "1.2.3.4";
            proxied = true;
          };
        };
        
        jellyfin = {
          host = {
            enable = true;
            domain = "jellyfin.example.com";
          };
          dns = {
            targetIp = "1.2.3.4";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable required modules
    homelab.dns.enable = mkIf (builtins.any (domain: domain.enable && domain.dns.enable) (builtins.attrValues cfg.domains)) true;
    homelab.reverseProxy.enable = mkIf (builtins.any (domain: domain.enable && domain.host.enable) (builtins.attrValues cfg.domains)) true;

    # Generate DNS records from domains
    homelab.dns.records = mapAttrs' (domainName: domain: 
      nameValuePair domainName {
        name = domain.host.domain;
        type = domain.dns.type;
        content = 
          if domain.dns.content != null then domain.dns.content
          else if config.homelab.dns.globalTargetIp != null then config.homelab.dns.globalTargetIp
          else throw "No targetIp specified for domain '${domainName}' and no globalTargetIp configured";
        proxied = domain.dns.proxied;
        ttl = domain.dns.ttl;
        comment = domain.dns.comment;
      }
    ) (filterAttrs (name: domain: domain.enable && domain.dns.enable) cfg.domains);

    # Generate reverse proxy hosts from domains
    homelab.reverseProxy.hosts = mapAttrs' (domainName: domain:
      nameValuePair domainName {
        enable = domain.host.enable;
        domain = domain.host.domain;
        backend = {
          address = domain.host.backend.address;
          port = domain.host.backend.port;
        };
        extraConfig = domain.host.extraConfig;
      }
    ) (filterAttrs (name: domain: domain.enable && domain.host.enable) cfg.domains);
  };
} 