{ config, pkgs, lib, ... }:

let
  cfg = config.remoteAccess.wireguard;
in {
  options.remoteAccess.wireguard = {
    enable = lib.mkEnableOption "wireguard";

    privateKeyFile = lib.mkOption {
      type = lib.types.str;
      description = "The path to the file containing the private key for this host (shared) between all interfaces";
    };

    host = {
      bridge = lib.mkOption {
        type = lib.types.str;
        description = "The name of the host bridge";
        default = "br0";
      };

      subnet = lib.mkOption {
        type = lib.types.str;
        description = "The subnet of the host";
        default = "192.168.11";
      };
    };

    interfaces = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "The name of the wireguard interface";
            example = "wg0";
          };

          externalInterface = lib.mkOption {
            type = lib.types.str;
            description = "The external interface to use for the wireguard interface";
            example = "br0";
          };

          port = lib.mkOption {
            type = lib.types.int;
            description = "The port to listen on";
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

                allowedPorts = lib.mkOption {
                  type = lib.types.nullOr (lib.types.listOf lib.types.int);
                  description = "The allowed ports of the peer";
                  default = null;
                };
              };
            });
            description = "List of WireGuard peers";
          };
        };
      });
    };
  };
  

  config = lib.mkIf cfg.enable {
    networking = {
      firewall = {
        allowedUDPPorts = [ cfg.port ];
      };

      nat = lib.mkMerge (map (interface: {
        ${interface.name} = {
          enable = true;
          internalInterfaces = [ interface.name ];
          externalInterface = interface.externalInterface;
        };
      }) cfg.interfaces);

      wireguard.interfaces = lib.mkMerge (map (interface: {
        ${interface.name} = {
          listenPort = interface.port;
          privateKeyFile = cfg.privateKeyFile;
          ips = interface.ips;

          peers = map (peer: {
            publicKey = peer.publicKey;
            allowedIPs = peer.allowedIPs;
          }) interface.peers;
        };
      }) cfg.interfaces);
    };
  };
}
