{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types;
  inherit (import ./network-types.nix { inherit lib; }) networkTypes;
in
{
  options.homelab.networks = {
    subnets = mkOption {
      type = types.attrsOf networkTypes.subnet;
      default = {}; 
      description = "Set of subnets to be used in the network";
    };
  };

  config = {
    homelab.networks.subnets = {
      "bln-lan" = {
        ipv4 = "192.168.11";
        ipv6 = "fd8f:2e0e:4eed";
        gateway6 = "fe80::be24:11ff:fee6:113b";
        vlan = 11;
      };
      "bln-apps" = {
        ipv4 = "10.10.44";
        vlan = 44;
      };
      "bln-mngmt" = {
        ipv4 = "10.10.55";
        vlan = 55;
      };
      "ldn" = {
        ipv4 = "10.11.20";
        ipv6 = "fd20:e376:b0a4";
        gateway6 = "fe80::d6da:21ff:fe75:37d";
        vlan = 10;
      };
      "tats" = {
        ipv4 = "192.168.178";
      };
    };
  };
}
