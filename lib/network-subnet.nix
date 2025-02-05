{ lib }:
let
  inherit (lib) types mkOption;
in {
  networkSubnet = types.submodule {
    options = {
      ipv4 = mkOption {
        type = types.str;
        description = "IPv4 subnet";
      };
      ipv6 = mkOption {
        type = types.str;
        description = "IPv6 subnet";
      };
      gateway = mkOption {
        type = types.str;
        description = "IPv4 gateway";
      };
      gateway6 = mkOption {
        type = types.str;
        description = "IPv6 gateway";
      };
    };
  };
}