{ config, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf mkMerge flatten optional hasSuffix listToAttrs;
  inherit (import ./network-types.nix { inherit lib; }) networkTypes;

  cfg = config.homelab.network;
  
  primaryBridges = builtins.filter (bridge: bridge.isPrimary) cfg.bridges;
  primaryBridgeCount = builtins.length primaryBridges;
  
  bridge = types.submodule ({ config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        description = "Interface name";
      };
      
      subnet = mkOption {
        type = types.nullOr networkTypes.subnet;
        default = null;
        description = "Reference to a subnet configuration or null for an empty bridge";
      };
      
      identifier = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Last octet of the interface IP";
      };

      address = mkOption {
        type = types.nullOr types.str;
        description = "Interface IP address";
        default = if config.subnet != null && config.identifier != null
                 then "${config.subnet.ipv4}.${config.identifier}"
                 else null;
      };

      address6 = mkOption {
        type = types.nullOr types.str;
        description = "Interface IPv6 address";
        default = if config.subnet != null && config.subnet.ipv6 != null && config.identifier != null then
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

      isPrimary = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this is the primary interface";
      };
    };
  });
in
{
  options.homelab.network = {
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
      type = types.listOf bridge;
    };

    primaryBridge = mkOption {
      type = types.nullOr bridge;
      description = "The primary bridge (automatically determined from bridges with isPrimary = true)";
      default = if primaryBridgeCount == 1 then builtins.head primaryBridges else null;
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

        # Bridge devices
        netdevs = mkMerge 
          (listToAttrs (map (bridge: {
            name = "10-${bridge.name}";
            value = {
              netdevConfig = {
                Name = bridge.name;
                Kind = "bridge";
              };
            };
          }) cfg.bridges));
        
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

          # Bridge interface settings - only for bridges with a subnet
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
              address = optional (bridge.address != null) "${bridge.address}/24"
                ++ optional (bridge.address6 != null) "${bridge.address6}/64";
              routes = optional (bridge.subnet != null) {
                Gateway = bridge.subnet.gateway;
                Metric = if bridge.isPrimary then 10 else 100;
              };
              dns = optional (bridge.subnet != null) bridge.subnet.gateway;
            };
          }) (builtins.filter (bridge: bridge.subnet != null) cfg.bridges)))
          
          # Empty bridge interface settings - for bridges without a subnet
          (listToAttrs (map (bridge: {
            name = "50-${bridge.name}";
            value = {
              matchConfig.Name = bridge.name;
              networkConfig = {
                ConfigureWithoutCarrier = true;
              };
            };
          }) (builtins.filter (bridge: bridge.subnet == null) cfg.bridges)))
        ];
      };
    })

    {
      assertions = [
        {
          assertion = primaryBridgeCount <= 1;
          message = "Only one bridge can have isPrimary = true. Found ${toString primaryBridgeCount} primary bridges: ${lib.concatMapStringsSep ", " (b: b.name) primaryBridges}";
        }
      ];
    }
  ];
}