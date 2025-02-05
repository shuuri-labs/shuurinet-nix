{config, lib, ...}:

let
  inherit (lib) mkOption types;
  inherit (import ../../lib/network-subnet.nix { inherit lib; }) networkSubnet;

  cfg = config.host.vars.network.config;
in
{
  options.host.vars.network.config = {
    hostName = mkOption {
      type = types.str;
      description = "Hostname for this machine";
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      description = "Network interfaces";
    };

    unmanagedInterfaces = mkOption {
      type = types.listOf types.str;
      description = "Network interfaces that should not be managed automatically by networkmanager";
    };

    bridge = mkOption {
      type = types.str;
      description = "Bridge interface name";
    };

    subnet = mkOption {
      type = networkSubnet;
      description = "Network subnet configuration";
    };

    hostIdentifier = mkOption {
      type = types.str;
      description = "Host identifier (last part of the host address)";
    };

    hostAddress = mkOption {
      type = types.str;
      description = "Host IPv4 address";
      default = "${cfg.subnet.ipv4}.${cfg.hostIdentifier}";
    };

    hostAddress6 = mkOption {
      type = types.str;
      description = "Host IPv6 address";
      default = "${cfg.subnet.ipv6}::${cfg.hostIdentifier}";
    };
  };
}
