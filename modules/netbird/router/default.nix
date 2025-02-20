{ config, pkgs, lib, ... }:

let
  cfg = config.netbird.router;
  containerTemplate = import ../../../lib/container-templates/host-network-container.nix {
    inherit config lib pkgs;
    stateVersion = config.system.stateVersion;
  };

  # Simplified container configuration function
  mkNetbirdContainer = name: peerConfig: {
    "netbird-${name}" = lib.mkIf peerConfig.enable (
      containerTemplate.base {
        name = "netbird-${name}";
        interface = peerConfig.hostInterface;
        subnet = peerConfig.hostSubnet;
        address = peerConfig.address;
        gateway = peerConfig.hostGateway;
        autoStart = true;
        extraConfig = {
          # Use host's netbird package
          nixpkgs.overlays = [
            (final: prev: {
              netbird = pkgs.netbird; 
            })
          ];

          # Enable NAT
          boot.kernel.sysctl = {
            "net.ipv4.ip_forward" = 1;
          };

          networking = {
            nftables = {
              enable = true;
              ruleset = ''
                table ip nat {
                  chain postrouting {
                    type nat hook postrouting priority 100;
                    oifname "eth0" masquerade
                  }
                }
              '';
            };
          };

          services.netbird.enable = true;

          systemd.services.netbird-setup = {
            description = "Setup Netbird connection";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            
            # create 'setup-complete' file in netbird dir if it doesn't exist 
            # signalling we don't need to run our setup command service again
            # TODO: this 'setup complete' logic is useful. extract it and place in lib
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = let
                script = pkgs.writeShellScript "netbird-setup" ''
                  if [ -f /var/lib/netbird/setup-complete ]; then
                    echo "Netbird already configured, skipping setup"
                    exit 0
                  fi
                  
                  setup_key=$(cat ${peerConfig.setupKey})
                  management_url=$(cat ${cfg.managementUrlPath})
                  ${pkgs.netbird}/bin/netbird up \
                    --management-url="$management_url:443" \
                    --admin-url="$management_url" \
                    --setup-key="$setup_key"
                    
                  touch /var/lib/netbird/setup-complete
                '';
              in "${script}";
            };
          };
        };
      } // {  # Merge additional container-level settings
        bindMounts = {
          "${peerConfig.setupKey}" = {
            hostPath = peerConfig.setupKey;
            isReadOnly = true;
          };
          "${cfg.managementUrlPath}" = {
            hostPath = cfg.managementUrlPath;
            isReadOnly = true;
          };
        };
      }
    );
  };
in

{
  options.netbird.router = {
    enable = lib.mkEnableOption "netbird router";

    peers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "netbird peer";
          
          address = lib.mkOption {
            type = lib.types.str;
            description = "Last octet of the IP address";
          };

          setupKey = lib.mkOption {
            type = lib.types.str;
            description = "Path to the Netbird setup key for this peer";
          };

          hostSubnet = lib.mkOption {
            type = lib.types.str;
            default = cfg.hostSubnet;
            description = "Subnet for this peer (defaults to global hostSubnet)";
          };

          hostInterface = lib.mkOption {
            type = lib.types.str;
            default = cfg.hostInterface;
            description = "Interface for this peer (defaults to global hostInterface)";
          };

          hostGateway = lib.mkOption {
            type = lib.types.str;
            default = cfg.hostGateway;
            description = "Gateway for this peer (defaults to global hostGateway)";
          };
        };
      });
      default = {};
      description = "Netbird peer configurations";
    };

    managementUrlPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Netbird management server URL";
    };

    hostSubnet = lib.mkOption {
      type = lib.types.str;
    };

    hostInterface = lib.mkOption {
      type = lib.types.str;
    };

    hostGateway = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.hostSubnet}.1";
    };
  };

  config = lib.mkIf cfg.enable {
    netbird.router.peers = {
      master = {
        enable = false;
        address = "11";
      };
      apps = {
        enable = false;
        address = "12";
      };
    };

    containers = lib.mkMerge (lib.mapAttrsToList mkNetbirdContainer cfg.peers);
  };
}