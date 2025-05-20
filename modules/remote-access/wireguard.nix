{ config, pkgs, lib, ... }:

let
  cfg = config.remoteAccess.wireguard;
in {
  options.remoteAccess.wireguard = {
    enable = lib.mkEnableOption "wireguard";

      port = lib.mkOption {
        type = lib.types.int;
        description = "The port to listen on";
        default = 58120;
      };

      interface = lib.mkOption {
        type = lib.types.str;
        description = "The name of the wireguard interface";
        default = "wg10";
      };

      privateKeyFile = lib.mkOption {
        type = lib.types.str;
        description = "The path to the file containing the private key";
      };

      addresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;  
        description = "The addresses to assign to the wireguard interface";
      };

      peers = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
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
      };
    };
  

  config = lib.mkIf cfg.enable {
    networking.wireguard.interfaces = {
      ${cfg.interface} = {
        listenPort = cfg.port;

        privateKeyFile = cfg.privateKeyFile;
        addresses = cfg.addresses;

        peers = cfg.peers;
      };
    };
  };
}
