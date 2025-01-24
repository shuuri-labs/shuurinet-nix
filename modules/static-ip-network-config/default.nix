{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  cfg = config.host.static-ip-network-config;
in
{
  options.host.static-ip-network-config = {
    network-config = mkOption {
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
            type = types.attrs;
            description = ''Network subnet configuration including: 
             gateway, gateway6, ipv4, ipv6
             see options-homelab/networks.nix (perhaps try to decouple in future)
            '';
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
      hostName = cfg.network-config.hostName;
      enableIPv6 = true;
      
      networkmanager = {
        enable = true;
        unmanaged = cfg.network-config.unmanagedInterfaces;
      };
    };

    systemd.network = {
      enable = true;

      # Define the bridge netdev
      netdevs."50-br0" = {
        netdevConfig = {
          Name = cfg.network-config.bridge;
          Kind = "bridge";
        };
      };

      # Configure each ethernet port to be part of the bridge
      networks = lib.listToAttrs (map (iface: {
        name = "50-${iface}";
        value = {
          matchConfig.Name = iface;
          networkConfig = {
            Bridge = cfg.network-config.bridge;
            # Ensure interface is managed by systemd-networkd
            ConfigureWithoutCarrier = true;
          };
        };
      }) cfg.network-config.interfaces) // {
        # Bridge interface configuration
        "50-br0" = {
          matchConfig.Name = cfg.network-config.bridge;
          networkConfig = {
            DHCP = "no";
            IPv6AcceptRA = true;  # Enable SLAAC for global address
            IPv6LinkLocalAddressGenerationMode = "eui64";
            ConfigureWithoutCarrier = true;
          };
          address = [
            cfg.network-config.hostAddress
            cfg.network-config.hostAddress6
          ];
          routes = [
            { 
              Gateway = cfg.network-config.subnet.gateway;
            }
          ];
          # DNS settings
          dns = [ cfg.network-config.subnet.gateway ];
        };
      };
    };
  };
}