{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;

  cfg = config.mediaServer.vpnConfinement;

  # Function to map ports to portMappings
  generatePortMappings = portsToForward: protocol:
    lib.concatMap (port: {
      from = port;
      to = port;
      protocol = protocol;
    }) portsToForward;
in
{
  options.mediaServer.vpnConfinement = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable VPN confinement service";
    };

    wireguardConfigFile = lib.mkOption {
      type = types.path; 
      default = "/secrets/wg0.conf";
      description = "Wireguard config file path";
    };

    lanSubnet = lib.mkOption {
      type = types.str; 
      default = "192.168.1";
      description = "LAN subnet for host machine";
    };

    lanSubnet6 = lib.mkOption {
      type = types.str;
      default = "fd00::1";
      description = "LAN subnet for host machine";
    };

    namespace = lib.mkOption {
      type = types.str; 
      default = "wg";
      description = "VPN namespace. Limited to 7 characters";
    };

    tcpPortsToForward = lib.mkOption {
      type = types.listOf types.port;
      default = [];
      description = "TCP ports that should be forwarded outside of the VPN tunnel to the host";
    };

    udpPortsToForward = lib.mkOption {
      type = types.listOf types.port;
      default = [];
      description = "UDP ports that should be forwarded outside of the VPN tunnel to the host";
    };

    bothPortsToForward = lib.mkOption {
      type = types.listOf types.port;
      default = [];
      description = "UDP ports that should be forwarded outside of the VPN tunnel to the host";
    };
  };

  config = lib.mkIf cfg.enable {
    vpnNamespaces."${cfg.namespace}" = {
      enable = true;
      wireguardConfigFile = cfg.wireguardConfigFile;
      accessibleFrom = [
        "192.168.0.0/16"
      ];
      portMappings = [
        { from = 9091; to = 9091; protocol = "tcp"; } # transmission
      ];
      openVPNPorts = [{
        port = 51413;
        protocol = "both";
      }];
    };
  };
}