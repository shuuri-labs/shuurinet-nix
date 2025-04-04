{ config, lib, ... }:
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

          egressTagged = mkOption {
            type = types.bool;
            default = false;
            description = "If false, egress traffic will be untagged; if true, egress tags are preserved.";
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
          name = "50-${bridge.name}";
          value = {
            netdevConfig = {
              Name = bridge.name;
              Kind = "bridge";
            };
          } 
          // (lib.optionalAttrs (bridge.vlan != null) {
            bridgeConfig = {
              VLANFiltering = true;
              DefaultPVID = bridge.vlan;
            };
          });
        }) cfg.bridges))

        # VLAN netdevs: create separate netdevs for each physical interface that requires a VLAN
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
                  EgressUntagged = lib.optional (!bridge.egressTagged) bridge.vlan;
                };
              };
            }) bridge.bridgedInterfaces)
        ) cfg.bridges)))
      ];

      networks = lib.mkMerge [
        # Configure physical interfaces attached to a bridge
        (lib.listToAttrs (lib.flatten (map (bridge:
          map (iface: {
            name = "30-${iface}";
            value = {
              matchConfig.Name = iface;
              networkConfig = {
                Bridge = bridge.name;
                ConfigureWithoutCarrier = true;
              };
            } // (lib.optionalAttrs (bridge.vlan != null) {
              # Attach VLAN netdev names to the physical interface
              vlan = [ "${iface}.${toString bridge.vlan}" ];
            });
          }) bridge.bridgedInterfaces
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
            };
            dns = bridge.dnsServers;
            bridgeVLANs = lib.optional (bridge.vlan != null) {
              VLAN = bridge.vlan;
              PVID = bridge.vlan;
              EgressUntagged = lib.optional (!bridge.egressTagged) bridge.vlan;
            };
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
      # …and the VLAN netdevs (using the naming from our "20-..." keys)
      (lib.flatten (map (bridge:
        lib.optionals (bridge.vlan != null)
          (map (iface: "${iface}.${toString bridge.vlan}") bridge.bridgedInterfaces)
      ) cfg.bridges))
      ++
      cfg.unmanagedInterfaces;
  };
}
