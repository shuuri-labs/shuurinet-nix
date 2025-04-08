{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (import ../../lib/network/network-types.nix { inherit lib; }) networkTypes;

  cfg = config.host.vars.network;
in
{
  options.host.vars.network = {
    hostName = mkOption {
      type = types.str;
      description = "Hostname for this machine";
    };

    enableIPv6 = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable IPv6";
    };

    staticIpConfig.enable = lib.mkEnableOption "staticNetworkConfig";

    # Network manager is now a separate option
    networkManager = {
      enable = mkOption {
        type = types.bool;
        default = true;  # Enable by default
        description = "Whether to enable NetworkManager";
      };

      unmanaged = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Interfaces that NetworkManager should not manage";
      };
    };

    bridges = mkOption {
      type = types.listOf (types.submodule ({ config, ... }: {
        options = {
          name = mkOption {
            type = types.str;
            description = "Interface name";
          };
          
          subnet = mkOption {
            type = networkTypes.subnet;
            description = "Reference to a subnet configuration";
          };
          
          identifier = mkOption {
            type = types.str;
            description = "Last octet of the interface IP";
          };

          address = mkOption {
            type = types.str;
            description = "Interface IP address";
            default = "${config.subnet.ipv4}.${config.identifier}";
          };

          address6 = mkOption {
            type = types.str;
            description = "Interface IPv6 address";
            default = if config.subnet.ipv6 != null then
              if lib.strings.hasSuffix "::" config.subnet.ipv6
                then "${config.subnet.ipv6}:${config.identifier}"
                else "${config.subnet.ipv6}::${config.identifier}"
              else null;
          };

          memberInterfaces = mkOption {
            type = types.listOf types.str;
            description = "List of member interfaces to attach to this bridge";
            default = [];
          };

          # TODO: implement this
          isPrimary = mkOption {
            type = types.bool;
            default = false;
              description = "Whether this is the primary interface";
            };
          };
      }));
    };
  };

  # Split into two config blocks
  config = lib.mkMerge [
    (lib.mkIf cfg.networkManager.enable {
      networking = {
        hostName = cfg.hostName;
        enableIPv6 = cfg.enableIPv6;

        networkmanager = {
          enable = true;
          unmanaged = cfg.networkManager.unmanaged;
        };
      };
    })

    (lib.mkIf cfg.staticIpConfig.enable {
      # Update unmanaged interfaces when static networking is enabled
      # add to option rather than networking.networkmanager.unmanaged directly to ensure proper merging
      host.vars.network.networkManager.unmanaged =  
        (map (bridge: bridge.name) cfg.bridges)
        ++
        (lib.flatten (map (bridge: bridge.memberInterfaces) cfg.bridges));

      systemd.network = {
        enable = true;

        # Define the bridge netdev
        netdevs = lib.mkMerge [
          (lib.listToAttrs (map (bridge: {
            name = "10-${bridge.name}";
            value = {
              netdevConfig = {
                Name = bridge.name;
                Kind = "bridge";
              };
            };
          }) cfg.bridges))
        ];

        # Configure each ethernet port to be part of the bridge
        networks = lib.mkMerge [
          (lib.listToAttrs (lib.flatten (map (bridge:
            (map (iface: {
              name = "30-${iface}";
              value = {
                matchConfig.Name = iface;
                networkConfig = {
                  Bridge = bridge.name;
                  ConfigureWithoutCarrier = true;
                };
              };
            }) bridge.memberInterfaces)
          ) cfg.bridges)))

          # Configure the bridge interface
          (lib.listToAttrs (map (bridge: {
            name = "50-${bridge.name}";
            value = {
              matchConfig.Name = bridge.name;
              networkConfig = {
                DHCP = "no";
                IPv6AcceptRA = true;
                IPv6LinkLocalAddressGenerationMode = "eui64";
                ConfigureWithoutCarrier = true;
              };
              address = [
                "${bridge.address}/24"
              ] ++ lib.optional (bridge.address6 != null) "${bridge.address6}/64";
              routes = [{ 
                Gateway = bridge.subnet.gateway;
                # ipv6 gateway/dns will be configured automatically by SLAAC
              }];
              dns = [ bridge.subnet.gateway ];
            };
          }) cfg.bridges))
        ];
      };
    })
  ];
}