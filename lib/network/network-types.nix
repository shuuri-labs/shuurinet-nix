{ lib, ... }:
let
  inherit (lib) types mkOption;
in {
  networkTypes = {
    subnet = types.submodule ({ config, ... }: {
      options = {
        ipv4 = mkOption {
          type = types.str;
          description = "IPv4 subnet prefix (e.g., 192.168.1)";
        };

        ipv6 = mkOption {
          type = types.nullOr types.str;
          description = "IPv6 subnet prefix";
          default = null;
        };

        gateway = mkOption {
          type = types.str;
          description = "IPv4 gateway";
          default = "${config.ipv4}.1";
        };

        gateway6 = mkOption {
          type = types.nullOr types.str;
          description = "IPv6 gateway";
          default = if config.ipv6 != null then
            if lib.strings.hasSuffix "::" config.ipv6
              then "${config.ipv6}1"
              else "${config.ipv6}::1"
            else null;
        };

        dnsServers = mkOption {
          type = types.listOf types.str;
          description = "DNS servers for this subnet";
          default = [ "${config.gateway}" ];
        };

        vlan = mkOption {
          type = types.nullOr types.int;
          description = "VLAN ID for this subnet";
          default = null;
        };
      };
    });
  };
}