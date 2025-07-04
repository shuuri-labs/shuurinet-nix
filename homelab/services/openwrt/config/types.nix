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

  wanConfigType = lib.types.submodule {
    options = {
      interface = lib.mkOption {
        type = lib.types.str;
        description = "WAN interface to use for the OpenWRT configuration";
        default = "wan";
      };

      protocol = lib.mkOption {
        type = lib.types.enum [ "dhcp" "pppoe" ];
        description = "Protocol to use for the WAN interface";
        default = "dhcp";
      };

      download = lib.mkOption {
        type = lib.types.int;
        description = "Download speed of the WAN interface for SQM";
        default = 0;
      };

      upload = lib.mkOption {
        type = lib.types.int;
        description = "Upload speed of the WAN interface for SQM";
        default = 0;
      };

      username = lib.mkOption {
        type = lib.types.str;
        description = "PPPoE Username for the WAN interface";
        default = "";
      };

      password = lib.mkOption {
        type = lib.types.str;
        description = "PPPoE Password for the WAN interface";
        default = "";
      };
    };
  };
}