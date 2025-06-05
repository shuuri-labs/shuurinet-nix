{ config, lib, pkgs, ... }:
let
  cfg = config.homelab;
  addProxy = import ./add-proxy.nix;
  
  # Filter hosts that have proxy enabled
  enabledProxyHosts = lib.filterAttrs (name: host: 
    host.proxy.enable
  ) cfg.reverseProxy.hosts;

  # Create virtual hosts for all enabled proxy hosts
  virtualHosts = lib.foldlAttrs (acc: hostName: hostConfig:
    acc // (addProxy {
      address = hostConfig.proxy.backend.address;
      port = hostConfig.proxy.backend.port;
      domain = hostConfig.proxy.domain;
    }).services.caddy.virtualHosts
  ) {} enabledProxyHosts;
in
{
  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts = virtualHosts;
  };
} 