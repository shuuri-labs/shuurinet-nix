{ lib, ... }:
let
  inherit (lib) types mkOption;
in {
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
        type = types.nullOr types.str;
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
        default = if config.gateway != null then [ "${config.gateway}" ] else [];
      };

      vlan = mkOption {
        type = types.nullOr types.int;
        description = "VLAN ID for this subnet";
        default = null;
      };
    };
  });

  staticHost = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Hostname for this static host";
      };

      ipv4 = mkOption {
        type = types.str;
        description = "IPv4 address for this static host";
      };

      mac = mkOption {
        type = types.str;
        description = "MAC address for this static host";
      };
    };
  };
}