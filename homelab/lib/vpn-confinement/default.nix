{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
  
  vpnConfinementTypes = import ./types.nix { inherit lib; };
  
  cfg = config.mediaServer.vpnConfinement;

  mkForwardPorts = lib.flatten (
    lib.mapAttrsToList (serviceName: serviceConfig: 
      let
        forwardPorts = serviceConfig.forwardPorts;
        tcpMappings = map (port: { from = port; to = port; protocol = "tcp"; }) forwardPorts.tcp;
        udpMappings = map (port: { from = port; to = port; protocol = "udp"; }) forwardPorts.udp;
        bothMappings = lib.flatten (map (port: [
          { from = port; to = port; protocol = "both"; }
        ]) forwardPorts.both);
      in
        tcpMappings ++ udpMappings ++ bothMappings
    ) cfg.services
  );

  mkOpenPorts = lib.flatten (
    lib.mapAttrsToList (serviceName: serviceConfig: 
      let
        openPorts = serviceConfig.openPorts;
        tcpMappings = map (port: { port = port; protocol = "tcp"; }) openPorts.tcp;
        udpMappings = map (port: { port = port; protocol = "udp"; }) openPorts.udp;
        bothMappings = map (port: { port = port; protocol = "both"; }) openPorts.both;
      in
        tcpMappings ++ udpMappings ++ bothMappings
    ) cfg.services
  );

  createConfinementServices = services:
    lib.mapAttrs' (serviceName: serviceConfig: {
      name = "${name}.vpnConfinement";
      value = {
        enable = serviceConfig.enable;
        namespace = cfg.namespace;
      };
  }) cfg.services;
in
{
  options.homelab.lib.vpnConfinement = {
    enable = lib.mkEnableOption "Enable VPN confinement service";

    namespace = { 
      name = lib.mkOption {
        type = types.str; 
        default = "vpncnf";
        description = "VPN namespace. Limited to 7 characters";
      };

      address = lib.mkOption {
        type = types.str;
        default = "192.168.15.1";
        description = "Address of the VPN confinement interface";
      };
    };

    wgConfigFile = lib.mkOption {
      type = types.path; 
      description = "Agenix encrypted wireguard config file path";
    };

    services = lib.mkOption {
      type = vpnConfinementTypes.serviceType;
      default = {};
      description = "Services to enable VPN confinement for";
    };

    hostSubnet = {
      ipv4 = lib.mkOption {
        type = types.str; 
        default = "192.168.1";
        description = "LAN subnet for host machine";
      };

      ipv6 = lib.mkOption {
        type = types.str;
        default = "";
        description = "LAN subnet for host machine";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create VPN namespace
    vpnNamespaces."${cfg.namespace.name}" = {
      enable = true;
      wireguardConfigFile = cfg.wgConfigFile;
      
      namespaceAddress = cfg.namespace.address;
      accessibleFrom = [
        "127.0.0.1/32"
        "${cfg.hostSubnet.ipv4}.0/24"
        "${cfg.hostSubnet.ipv6}::/64"
      ];
      portMappings = mkForwardPorts;
      openVPNPorts = mkOpenPorts;
    };

    systemd.services = createConfinementServices;
  };
}