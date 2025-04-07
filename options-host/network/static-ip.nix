{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.host.vars.network.staticIpConfig;
in {
  options.host.vars.network.staticIpConfig = {
    enable = lib.mkEnableOption "staticIpNetworkConfig";

    unmanagedInterfaces = mkOption {
      type = types.listOf types.str;
      description = "Network interfaces that should not be managed automatically by networkmanager";
      default = [];
    };

    enableSourceRouting = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''Enable source-based routing - required for multi-bridge setups with physical ports
        untested for multi-bridge setups with no physical ports (may/may not be needed)'';
    };

    bridges = mkOption {
      type = types.listOf (types.submodule ({ config, ... }: {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the bridge interface";
          };

          bridgedInterfaces = mkOption {
            type = types.listOf types.str;
            description = "List of physical interfaces to bridge";
            default = [];
          };

          identifier = mkOption {
            type = types.str;
            description = "Interface identifier (last octet of the bridge address)";
          };

          subnetIpv4 = mkOption {
            type = types.str;
            description = "IPv4 subnet";
          };

          subnetIpv6 = mkOption {
            type = types.nullOr types.str;
            description = "IPv6 subnet";
            default = null;
          };

          gatewayIpv4 = mkOption {
            type = types.str;
            description = "IPv4 gateway";
            default = "${config.subnetIpv4}.1";
          };
          
          dnsServers = mkOption {
            type = types.listOf types.str;
            description = "List of DNS servers";
            default = [ "${config.gatewayIpv4}" ];
          };

          vlan = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "VLAN ID for this bridge. If set, enables VLAN filtering.";
          };

          isPrimary = mkOption {
            type = types.bool;
            default = false;
            description = "Whether this bridge should be used as the primary default route";
          };
        };
      }));
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.network = {
      enable = true;

      netdevs = lib.mkMerge [
        # Bridge netdevs
        (lib.listToAttrs (map (bridge: {
          name = "10-${bridge.name}";
          value = {
            netdevConfig = {
              Name = bridge.name;
              Kind = "bridge";
            };
          };
        }) cfg.bridges))

        # loop bridge ports and create vlan subinterfaces for each
        (lib.listToAttrs (lib.flatten (map (bridge:
          lib.optionals (bridge.vlan != null)
            (map (iface: {
              name = "20-${iface}.${toString bridge.vlan}";
              value = {
                netdevConfig = {
                  Kind = "vlan";
                  Name = "${iface}.${toString bridge.vlan}";
                };
                vlanConfig = {
                  Id = bridge.vlan;
                };
              };
            }) bridge.bridgedInterfaces)
        ) cfg.bridges)))
      ];

      networks = lib.mkMerge [
        # Configure physical interfaces attached to a bridge
        (lib.listToAttrs (lib.flatten (map (bridge:
          if (bridge.vlan == null)
            then
            # If NO VLAN specified, add physical interface to bridge
            (map (iface: {
              name = "30-${iface}";
              value = {
                matchConfig.Name = iface;
                networkConfig = {
                  Bridge = bridge.name;
                  ConfigureWithoutCarrier = true;
                };
              };
            }) bridge.bridgedInterfaces)
            else
            # If VLAN specified, only set up VLAN tagging on physical interface but DON'T add to bridge
            (map (iface: {
              name = "30-${iface}";
              value = {
                matchConfig.Name = iface;
                networkConfig = {
                  ConfigureWithoutCarrier = true;
                };
                # Attach VLAN netdev names to the physical interface
                vlan = map (b: "${iface}.${toString b.vlan}") 
                  (lib.filter (b: b.vlan != null && lib.elem iface b.bridgedInterfaces) cfg.bridges);
              };
            }) bridge.bridgedInterfaces)
        ) cfg.bridges)))

        # Configure VLAN subinterface networks
        (lib.listToAttrs (lib.flatten (map (bridge:
          lib.optionals (bridge.vlan != null)
            (map (iface: {
              name = "40-${iface}.${toString bridge.vlan}";
              value = {
                matchConfig.Name = "${iface}.${toString bridge.vlan}";
                networkConfig = {
                  Bridge = bridge.name;
                  ConfigureWithoutCarrier = true;
                };
              };
            }) bridge.bridgedInterfaces)
        ) cfg.bridges)))

        # Configure the bridge interface networks
        (lib.listToAttrs (map (bridge: {
          name = "40-${bridge.name}";
          value = {
            matchConfig.Name = bridge.name;
            networkConfig = {
              DHCP = "no";
              IPv6AcceptRA = true;
              IPv6LinkLocalAddressGenerationMode = "eui64";
              ConfigureWithoutCarrier = true;
            };
            address = [] 
              ++ lib.optional (bridge.subnetIpv4 != null && bridge.subnetIpv4 != "") (
                "${bridge.subnetIpv4}.${bridge.identifier}/24"
              )
              ++ lib.optional (bridge.subnetIpv6 != null && bridge.subnetIpv6 != "") (
                "${bridge.subnetIpv6}${if lib.hasInfix "::" bridge.subnetIpv6 then ":" else "::"}${bridge.identifier}/64"
              );
            routes = lib.optional (bridge.gatewayIpv4 != null) {
              Gateway = bridge.gatewayIpv4;
              Metric = if bridge.isPrimary then 10 else 100;
            };
            dns = bridge.dnsServers;
          };
        }) cfg.bridges))
      ];
    };

    networking.networkmanager.unmanaged =
      # Unmanage bridges…
      (map (bridge: bridge.name) cfg.bridges)
      ++
      # …the physical interfaces…
      (lib.flatten (map (bridge: bridge.bridgedInterfaces) cfg.bridges))
      ++
      # …and the VLAN netdevs
      (lib.flatten (map (bridge:
        lib.optionals (bridge.vlan != null)
          (map (iface: "${iface}.${toString bridge.vlan}") bridge.bridgedInterfaces)
      ) cfg.bridges))
      ++
      cfg.unmanagedInterfaces;
    
    # Set up source-based routing when enabled
    systemd.services.setup-source-routing = lib.mkIf cfg.enableSourceRouting {
      description = "Setup source-based routing for multiple bridges";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ iproute2 ];
      
      script = let
        createSourceRoutingForBridge = bridge: ''
          # Create a routing table for this bridge (using vlan ID or a sequential number)
          TABLE_NUM=${if bridge.vlan != null then toString bridge.vlan else toString bridge.identifier}
          BRIDGE_IP=$(ip -4 addr show dev ${bridge.name} | grep -Po 'inet \K[\d.]+')
          
          # Skip if the bridge has no IP
          if [ -z "$BRIDGE_IP" ]; then
            echo "Bridge ${bridge.name} has no IPv4 address, skipping"
            continue
          fi
          
          # Create a specific routing table for this bridge
          ip route add default via ${bridge.gatewayIpv4} dev ${bridge.name} table $TABLE_NUM
          
          # Add a rule to use this table for traffic from this bridge's IP
          ip rule add from $BRIDGE_IP table $TABLE_NUM
        '';
      in ''
        # Flush existing rules (except local and main)
        ip rule flush
        ip rule add from all lookup local pref 0
        ip rule add from all lookup main pref 32766
        ip rule add from all lookup default pref 32767
        
        # Add rules for each bridge
        ${lib.concatMapStrings createSourceRoutingForBridge cfg.bridges}
        
        # Flush routing cache
        ip route flush cache
      '';
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
