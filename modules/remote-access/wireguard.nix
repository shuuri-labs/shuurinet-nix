{ config, pkgs, lib, ... }:

let
  cfg = config.remoteAccess.wireguard;
in {
  options.remoteAccess.wireguard = {
    enable = lib.mkEnableOption "wireguard";

    host.bridge = lib.mkOption {
      type = lib.types.str;
      description = "The name of the host bridge";
      default = "br0";
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

          ip = lib.mkOption {
            type = lib.types.str;
            description = "The IP address of the peer";
            example = "10.100.88.32/32";
          };
          
          allowedPorts = lib.mkOption {
            type = lib.types.attrsOf (lib.types.listOf lib.types.int);
            description = "The allowed IPs of the peer";
            default = {}; 
            example = {
              "tcp" = [ 22 8096 ];
            };
          };
        };
      });
      description = "List of WireGuard peers";
    };
  };
  

  config = lib.mkIf cfg.enable {
    networking = {
      firewall = {
        allowedUDPPorts = [ cfg.port ];

        extraCommands = ''
          # Accept only allowed ports from the peer's IP if allowedPorts is not null
          ${lib.concatStringsSep "\n" (map (peer:
            if peer.allowedPorts != null then
              lib.concatStringsSep "\n" (lib.mapAttrsToList (protocol: ports:
                lib.concatStringsSep "\n" (map (port:
                  # Allow specific port ${toString port} for ${peer.ip}
                  "iptables -I FORWARD 1 -i ${cfg.interface} -s ${peer.ip} -p ${protocol} --dport ${toString port} -j ACCEPT"
                ) ports)
              ) peer.allowedPorts)
            else
              ""
          ) cfg.peers)}

          # Block everything else from each peer's IP if allowedPorts is populated (or null)
          ${lib.concatStringsSep "\n" (map (peer:
            if peer.allowedPorts == null || peer.allowedPorts != {} then
              # Block all other traffic from ${peer.ip}
              "iptables -I FORWARD 2 -i ${cfg.interface} -s ${peer.ip} -j DROP"
            else
              ""
          ) cfg.peers)}
        '';
      };

      nat = {
        enable = true;
        internalInterfaces = [ cfg.interface ];
        externalInterface = cfg.host.bridge;
      };

      wireguard.interfaces = {
        ${cfg.interface} = {
          listenPort = cfg.port;

          privateKeyFile = cfg.privateKeyFile;
          ips = cfg.ips;

          peers = map (peer: {
            publicKey = peer.publicKey;
            allowedIPs = [ peer.ip ];
          }) cfg.peers;
        };
      };
    };
  };
}
