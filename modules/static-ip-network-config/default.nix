{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ../../lib/network-config.nix { inherit lib; }) networkSubnet;
  cfg = config.host.staticIpNetworkConfig;
in
{
  options.host.staticIpNetworkConfig = {
    networkConfig = mkOption {
      type = types.submodule {
        options = {
          hostName = mkOption {
            type = types.str;
            description = "Hostname of the host machine";
          };

          interfaces = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Interfaces to be used for the host machine";
          };

          unmanagedInterfaces = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Interfaces to be unmanaged by networkmanager";
          };

          bridge = mkOption {
            type = types.str;
            default = "br0";
            description = "Bridge name.";
          };

          subnet = mkOption {
            type = networkSubnet;
            description = "Network subnet configuration";
          };

          hostAddress = mkOption {
            type = types.str;
            description = "Host address for host machine";
          };

          hostAddress6 = mkOption {
            type = types.str;
            description = "Host address for host machine";
          };
        };
      };
    };
  };

  config = {
    networking = {
      hostName = cfg.networkConfig.hostName;
      enableIPv6 = true;
      
      # Enable networkmanager to configure interfaces that require auto configuration (like wireguard)
      networkmanager = {
        enable = true;
        unmanaged = cfg.networkConfig.unmanagedInterfaces;
      };
    };

    systemd.network = {
      enable = true;

      # Define the bridge netdev
      netdevs."50-br0" = {
        netdevConfig = {
          Name = cfg.networkConfig.bridge;
          Kind = "bridge";
        };
      };

      # Configure each ethernet port to be part of the bridge
      networks = lib.listToAttrs (map (iface: {
        name = "50-${iface}";
        value = {
          matchConfig.Name = iface;
          networkConfig = {
            Bridge = cfg.networkConfig.bridge;
            # Ensure interface is managed by systemd-networkd
            ConfigureWithoutCarrier = true;
          };
        };
      }) cfg.networkConfig.interfaces) // {
        # Bridge interface configuration
        "50-br0" = {
          matchConfig.Name = cfg.networkConfig.bridge;
          networkConfig = {
            DHCP = "no";
            IPv6AcceptRA = true;  # Enable SLAAC for global address
            IPv6LinkLocalAddressGenerationMode = "eui64";
            ConfigureWithoutCarrier = true;
          };
          address = [
            "${cfg.networkConfig.hostAddress}/24"
            "${cfg.networkConfig.hostAddress6}/64"
          ];
          routes = [{ 
            Gateway = cfg.networkConfig.subnet.gateway;
            # ipv6 gateway/dns will be configured automatically by SLAAC
          }];
          dns = [ cfg.networkConfig.subnet.gateway ];
        };
      };
    };
  };
}