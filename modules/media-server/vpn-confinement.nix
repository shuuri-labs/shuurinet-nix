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
      description = "VPN namespace";
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
    # Service ports to forward out of VPN interface (transmission, bazarr, radarr, sonarr, prowlarr)
    # mediaServer.vpnConfinement.tcpPortsToForward = [ 9091 6767 7878 8989 9696 ];

    vpnNamespaces."${cfg.namespace}" = { # The name is limited to 7 characters
      enable = true;
      wireguardConfigFile = cfg.wireguardConfigFile;
      accessibleFrom = [
        "${cfg.lanSubnet}.0/24"
        "${cfg.lanSubnet6}::/64"
      ];
      portMappings = [
        { from = 9091; to = 9091; protocol = "tcp"; }
        { from = 6767; to = 6767; protocol = "tcp"; }
        { from = 7878; to = 7878; protocol = "tcp"; }
        { from = 8989; to = 8989; protocol = "tcp"; }
        { from = 9696; to = 9696; protocol = "tcp"; }
        # TODO: fix, portMappings = lib.concatMap [ ... ]
        # (generatePortMappings cfg.tcpPortsToForward "tcp")
        # (generatePortMappings cfg.udpPortsToForward "udp")
        # (generatePortMappings cfg.bothPortsToForward "both")
      ];
    };
  };
}