{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types;
  inherit (import ../lib/network-subnet.nix { inherit lib; }) networkSubnet;
in
{
  options.homelab.networks = {
    subnets = mkOption {
      type = types.attrsOf networkSubnet;
      default = {}; 
      description = "Set of subnets to be used in the network";
    };
  };

  config = {
    homelab.networks.subnets = {
      "bln" = {
        ipv4 = "192.168.11";
        ipv6 = "fd8f:2e0e:4eed";
        gateway = "${config.homelab.networks.subnets.bln.ipv4}.1";
        gateway6 = "${config.homelab.networks.subnets.bln.ipv6}::1";
      };
      "ldn" = {
        ipv4 = "10.11.20";
        ipv6 = " fd20:e376:b0a4"; # TODO: change from link local
        gateway = "${config.homelab.networks.subnets.ldn.ipv4}.1";
        gateway6 = "${config.homelab.networks.subnets.ldn.ipv6}::1";
      };
      "tats" = {
        ipv4 = "192.168.178";
        ipv6 = "";
        gateway = "192.168.178.1";
        gateway6 = "";
      };
    };
  };
}
