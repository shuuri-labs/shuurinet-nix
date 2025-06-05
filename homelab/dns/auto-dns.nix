{ config, lib, pkgs, ... }:
let
  cfg = config.homelab;
  
  # Filter hosts that have DNS enabled
  enabledDnsHosts = lib.filterAttrs (name: host: 
    host.dns.enable
  ) cfg.reverseProxy.hosts;

  # Create DNS records for enabled DNS hosts when auto-management is enabled
  autoDnsRecords = lib.optionals (cfg.dns.enable && cfg.dns.autoManage) 
    (lib.mapAttrsToList (hostName: hostConfig: {
      name = hostConfig.proxy.domain;
      type = hostConfig.dns.type;
      content = hostConfig.dns.targetIp or cfg.dns.cloudflare.publicIp;
      proxied = hostConfig.dns.proxied;
      ttl = hostConfig.dns.ttl;
      comment = if hostConfig.dns.comment != "" 
                then hostConfig.dns.comment 
                else "Auto-managed by homelab DNS for ${hostName}";
    }) enabledDnsHosts);
in
{
  config = lib.mkIf cfg.enable {
    # Automatically add DNS records from host configurations
    homelab.dns.records = autoDnsRecords;
  };
} 