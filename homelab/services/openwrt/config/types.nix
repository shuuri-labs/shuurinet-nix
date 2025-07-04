{ lib, ... }:
{
  interfaceType = lib.types.submodule {
    options = {
      # name = lib.mkOption {
      #   type = lib.types.str;
      #   description = "Name of the bridge";
      # };

      vlanId = lib.mkOption {
        type = lib.types.int;
        description = "VLAN ID of the interface";
      };

      ports = lib.mkOption { 
        type = lib.types.listOf lib.types.str;
        description = "Ports associated with the interface";
      };

      trunkPorts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Trunk ports of the interface";
      };

      address.prefix = lib.mkOption {
        type = lib.types.str;
        description = "First 3 octets of the interface's IPv4 address";
      };

      forwards = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Interfaces to forward traffic to";
        default = [];
      };

      isPrivileged = lib.mkOption {
        type = lib.types.bool;
        description = "Whether the bridge is privileged";
        default = false;
      };

      isPrimary = lib.mkOption {
        type = lib.types.bool;
        description = "Whether the bridge is the primary bridge";
        default = false;
      };

      wifi = {
        enable = lib.mkEnableOption "Enable WiFi for this interface";

        ssid = lib.mkOption {
          type = lib.types.str;
          description = "SSID of the WiFi network";
        };

        password = lib.mkOption {
          type = lib.types.str;
          description = "Password of the WiFi network";
        };

        frequency = lib.mkOption {
          type = lib.types.enum [ "2.4" "5" "both" ];
          description = "Frequency of the WiFi network";
        };
      };
    };
  };

  configDefinitionType = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "OpenWRT configuration";

      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the OpenWRT configuration file";
      };

      config = lib.mkOption {
        type = lib.types.attrs;
        description = "OpenWRT configuration";
      };

      system = lib.mkOption {
        type = lib.types.str;
        description = "System to build the configuration for";
        default = "x86_64-linux";
      };

      isRouter = lib.mkOption {
        type = lib.types.bool;
        description = "Whether this configuration is a router";
        default = false;
      };
    };
  };
}