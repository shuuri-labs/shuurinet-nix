{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.homelab.networks = {
    subnets = mkOption {
      type = types.attrsOf (types.submodule ({ config, ... }: {
        options = {
          ipv4 = mkOption {
            type = types.str;
            description = "IPv4 subnet";
          };

          ipv6 = mkOption {
            type = types.str;
            description = "IPv6 subnet";
            default = "";
          };

          gateway = mkOption {
            type = types.str;
            description = "IPv4 gateway";
            default = "${config.ipv4}.1";
          };

          gateway6 = mkOption {
            type = types.str;
            description = "IPv6 gateway";
            default = "";
          };
          
          vlan = mkOption {
            type = types.int;
            description = "VLAN ID";
          };
        };
      }));
    };
  };

  config = {
    homelab.networks.subnets = {
      "bln" = {
        ipv4 = "192.168.11";
        ipv6 = "fd8f:2e0e:4eed";
        vlan = 11;
      };

      "bln-apps" = {
        ipv4 = "10.10.44";
        vlan = 44;
      };

      "bln-mgmt" = {
        ipv4 = "10.10.55";
        vlan = 55;
      };

      "ldn" = {
        ipv4 = "10.11.20";
        ipv6 = "fe80::d6da:21ff:fe75:37d"; # TODO: change from link local
        vlan = 10; 
      };
      
      "tats" = {
        ipv4 = "192.168.178";
      };
    };
  };
}
