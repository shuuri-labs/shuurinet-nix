{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  hostNetworkCfgVars = config.host.vars.network.config;
  cfg = config.host.vars.network.staticIpConfig;
in
{
  options.host.vars.network.staticIpConfig = {
    enable = lib.mkEnableOption "staticIpNetworkConfig";
  };

  config = lib.mkIf cfg.enable {
    networking = {
      hostName = hostNetworkCfgVars.hostName;
      enableIPv6 = true;
      
      # Enable networkmanager to configure interfaces that require auto configuration (like wireguard)
      networkmanager = {
        enable = true;
        unmanaged = hostNetworkCfgVars.unmanagedInterfaces;
      };
    };

    systemd.network = {
      enable = true;

      # Define the bridge netdev
      netdevs."50-br0" = {
        netdevConfig = {
          Name = hostNetworkCfgVars.bridge;
          Kind = "bridge";
        };
      };

      # Configure each ethernet port to be part of the bridge
      networks = lib.listToAttrs (map (iface: {
        name = "50-${iface}";
        value = {
          matchConfig.Name = iface;
          networkConfig = {
            Bridge = hostNetworkCfgVars.bridge;
            # Ensure interface is managed by systemd-networkd
            ConfigureWithoutCarrier = true;
          };
        };
      }) hostNetworkCfgVars.interfaces) // {
        # Bridge interface configuration
        "50-br0" = {
          matchConfig.Name = hostNetworkCfgVars.bridge;
          networkConfig = {
            DHCP = "no";
            IPv6AcceptRA = true;  # Enable SLAAC for global address
            IPv6LinkLocalAddressGenerationMode = "eui64";
            ConfigureWithoutCarrier = true;
          };
          address = [
            "${hostNetworkCfgVars.hostAddress}/24"
            "${hostNetworkCfgVars.hostAddress6}/64"
          ];
          routes = [{ 
            Gateway = hostNetworkCfgVars.subnet.gateway;
            # ipv6 gateway/dns will be configured automatically by SLAAC
          }];
          dns = [ hostNetworkCfgVars.subnet.gateway ];
        };
      };
    };
  };
}