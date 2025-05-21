{ config, pkgs, lib, ... }:

let
  cfg = config.remoteAccess.wireguard;
in {
  options.remoteAccess.wireguard = {
    enable = lib.mkEnableOption "wireguard";

    host = {
      bridge = lib.mkOption {
        type = lib.types.str;
        description = "The name of the host bridge";
        default = "br0";

        subnet = lib.mkOption {
          type = lib.types.str;
          description = "The subnet of the host";
          default = "192.168.11";
        };
      };
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.str;
      description = "The path to the file containing the private key";
    };

    port = lib.mkOption {
      type = lib.types.int;
      description = "The port to listen on";
      default = 58133;
    };

    interface = lib.mkOption {
      type = lib.types.str;
      description = "The name of the wireguard interface";
      default = "wg10";
    };

    ips = lib.mkOption {
      type = lib.types.listOf lib.types.str;  
      description = "The addresses to assign to the wireguard interface";
    };

    peers = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the peer (for reference)";
          };

          publicKey = lib.mkOption {
            type = lib.types.str;
            description = "The public key of the peer";
          };
          
          allowedIPs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "The allowed IPs of the peer";
          };
        };
      });
      description = "List of WireGuard peers";
    };
  };
  

  config = lib.mkIf cfg.enable {
    networking = {
      firewall.trustedInterfaces = [ cfg.interface ];
      firewall.allowedUDPPorts = [ cfg.port ];

      nat = {
        enable = true;
        internalInterfaces = [ cfg.interface ];
        externalInterface = cfg.hostBridge;
      };

      wireguard.interfaces = {
        ${cfg.interface} = {
          listenPort = cfg.port;

          privateKeyFile = cfg.privateKeyFile;
          ips = cfg.ips;

          peers = map (peer: {
            publicKey = peer.publicKey;
            allowedIPs = peer.allowedIPs;
          }) cfg.peers;

          postSetup = ''
            ip route add ${cfg.host.subnet}.0/24 dev ${cfg.host.bridge} table main
          '';
        };
      };
    };
  };
}
