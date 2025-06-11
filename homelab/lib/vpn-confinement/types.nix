{ lib }:
let
  inherit (lib) types;
in
{
  vpnPortsType = types.submodule {
    options = {
      tcp = lib.mkOption {
        type = types.listOf (types.addCheck types.int (port: port >= 1 && port <= 65535));
        default = [];
        description = "TCP ports to forward from (1-65535)";
      };

      udp = lib.mkOption {
        type = types.listOf (types.addCheck types.int (port: port >= 1 && port <= 65535));
        default = [];
        description = "UDP ports to forward from (1-65535)";
      };

      both = lib.mkOption {
        type = types.listOf (types.addCheck types.int (port: port >= 1 && port <= 65535));
        default = [];
        description = "Ports to forward from both TCP and UDP (1-65535)";
      };
    };
  };

  serviceType = types.attrsOf (types.submodule ({ name, ... }: {
    options = {
      enable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Enable VPN confinement for the service";
      };

      name = lib.mkOption {
        type = types.str;
        default = name;
        readOnly = true;
        description = "Name of the confined service";
      };

      namespace = lib.mkOption {
        type = types.str;
        default = "vpncnf";
        description = "VPN namespace. Limited to 7 characters";
      };

      forwardPorts = lib.mkOption {
        type = vpnPortsType;
        default = {};
        description = "Ports to forward from confined service to host";
      };

      openPorts = lib.mkOption {  
        type = vpnPortsType;
        default = {};
        description = "Ports to open in VPN.";
      };
    };
  }));
}