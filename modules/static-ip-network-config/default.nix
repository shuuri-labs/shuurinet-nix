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
      networkmanager.enable = true;

      bridges.${cfg.network-config.bridge} = {
        interfaces = cfg.network-config.interfaces;
      };

      interfaces.${cfg.network-config.bridge} = {
        ipv4 = {
          addresses = [{
            address = cfg.network-config.hostAddress;
            prefixLength = 24;
          }];
        };

        ipv6 = {
          addresses = [{
            address = cfg.network-config.hostAddress6; 
            prefixLength = 64;
          }];
        };
      };

      defaultGateway = {
        address = cfg.network-config.subnet.gateway;
        interface = cfg.network-config.bridge;
      };

      defaultGateway6 = {
        address = cfg.network-config.subnet.gateway6;
        interface = cfg.network-config.bridge;
      };

      nameservers = [ 
        cfg.network-config.subnet.gateway
      ];
    };
  };
}