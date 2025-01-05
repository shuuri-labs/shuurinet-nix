{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.homelab.networks = {
    subnets = mkOption {
      type = types.attrsOf (types.submodule {  # Changed from listOf to attrsOf with submodule
        options = {
          ipv4 = mkOption {
            type = types.str;
            description = "IPv4 subnet";
          };
          ipv6 = mkOption {
            type = types.str;
            description = "IPv6 subnet";
          };
        };
      });
      default = {};  # Changed from [] to {}
      description = "Set of subnets to be used in the network";
    };
  };

  config = {
    homelab.networks.subnets = {
      "bln" = {
        ipv4 = "192.168.11";
        ipv6 = "fd8f:2e0e:4eed";
      };
      "ldn" = {
        ipv4 = "10.11.20";
        ipv6 = " fd20:e376:b0a4";
      };
      "tats" = {
        ipv4 = "192.168.178";
        ipv6 = "";
      };
    };
  };
}
