{ config, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf mkMerge flatten optional hasSuffix listToAttrs;
  inherit (import ../../lib/network/network-types.nix { inherit lib; }) networkTypes;

  cfg = config.host.vars.network;

  # Collect all tap devices with their parent bridge name
  allTapDevices = flatten (map (bridge:
    map (tap: {
      name = tap;
      bridge = bridge.name;
    }) bridge.tapDevices
  ) cfg.bridges);
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

    staticIpConfig.enable = mkEnableOption "staticNetworkConfig";

    networkManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
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
              if hasSuffix "::" config.subnet.ipv6
                then "${config.subnet.ipv6}:${config.identifier}"
                else "${config.subnet.ipv6}::${config.identifier}"
              else null;
          };

          memberInterfaces = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of member interfaces to attach to this bridge";
          };
          
          tapDevices = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "TAP interfaces to attach to this bridge";
          };

          isPrimary = mkOption {
            type = types.bool;
            default = false;
            description = "Whether this is the primary interface";
          };
        };
      }));
    };
  };

  config = mkMerge [
    (mkIf cfg.networkManager.enable {
      networking = {
        hostName = cfg.hostName;
        enableIPv6 = cfg.enableIPv6;

        networkmanager = {
          enable = true;
          unmanaged = cfg.networkManager.unmanaged;
        };
      };
    })

    (mkIf cfg.staticIpConfig.enable {
      # Mark bridge and member interfaces as unmanaged for NetworkManager
      host.vars.network.networkManager.unmanaged =  
        (map (bridge: bridge.name) cfg.bridges)
        ++
        (flatten (map (bridge: bridge.memberInterfaces) cfg.bridges))
        ++
        (map (tap: tap.name) allTapDevices);

      systemd.network = {
        enable = true;

        # Bridge devices and TAP devices
        netdevs = mkMerge [
          (listToAttrs (map (bridge: {
            name = "10-${bridge.name}";
            value = {
              netdevConfig = {
                Name = bridge.name;
                Kind = "bridge";
              };
            };
          }) cfg.bridges))
          
          (listToAttrs (map (tap: {
            name = "90-${tap.name}";
            value = {
              netdevConfig = {
                Name = tap.name;
                Kind = "tap";
              };
            };
          }) allTapDevices))
        ];

        # Interfaces (ethernet, tap) attached to bridges
        networks = mkMerge [
          # Bridge member physical interfaces
          (listToAttrs (flatten (map (bridge:
            map (iface: {
              name = "30-${iface}";
              value = {
                matchConfig.Name = iface;
                networkConfig = {
                  Bridge = bridge.name;
                  ConfigureWithoutCarrier = true;
                };
              };
            }) bridge.memberInterfaces
          ) cfg.bridges)))

          # Bridge interface settings
          (listToAttrs (map (bridge: {
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
              ] ++ optional (bridge.address6 != null) "${bridge.address6}/64";
              routes = [{
                Gateway = bridge.subnet.gateway;
                Metric = if bridge.isPrimary then 10 else 100;
              }];
              dns = [ bridge.subnet.gateway ];
            };
          }) cfg.bridges))
          
          # TAP interfaces
          (listToAttrs (map (tap: {
            name = "90-${tap.name}";
            value = {
              matchConfig.Name = tap.name;
              networkConfig = {
                Bridge = tap.bridge;
                ConfigureWithoutCarrier = true;
              };
            };
          }) allTapDevices))
        ];
      };
    })
  ];
}