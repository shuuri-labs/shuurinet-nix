{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
  
  vpnConfinementTypes = import ./types.nix { inherit lib; };
  
  cfg = config.homelab.vpnConfinement;

  # Check if any service has VPN confinement enabled
  anyServiceEnabled = lib.any (serviceConfig: serviceConfig.enable) (lib.attrValues cfg.services);

  mkForwardPorts = services: lib.flatten (
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
    ) services
  );

  mkOpenPorts = services: lib.flatten (
    lib.mapAttrsToList (serviceName: serviceConfig: 
      let
        openPorts = serviceConfig.openPorts;
        tcpMappings = map (port: { port = port; protocol = "tcp"; }) openPorts.tcp;
        udpMappings = map (port: { port = port; protocol = "udp"; }) openPorts.udp;
        bothMappings = map (port: { port = port; protocol = "both"; }) openPorts.both;
      in
        tcpMappings ++ udpMappings ++ bothMappings
    ) services
  );

  createConfinementServices = services:
    lib.mapAttrs' (serviceName: serviceConfig: {
      name = serviceName;
      value = {
        vpnConfinement = {
          enable = serviceConfig.enable;
          vpnNamespace = cfg.namespace.name;
        };
      };
  }) services;
in
{
  options.homelab.vpnConfinement = {
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
      type = types.attrsOf vpnConfinementTypes.serviceType;
      default = {};
      description = "Services to enable VPN confinement for";
    };

    hostSubnet = {
      ipv4 = lib.mkOption {
        type = types.str; 
        default = "";
        description = "LAN subnet for host machine";
      };

      ipv6 = lib.mkOption {
        type = types.str;
        default = "";
        description = "LAN subnet for host machine";
      };
    };
  };

  config = lib.mkIf (cfg.enable || anyServiceEnabled) {
    vpnNamespaces."${cfg.namespace.name}" = {
      enable = true;
      wireguardConfigFile = cfg.wgConfigFile;

      namespaceAddress = cfg.namespace.address;
      accessibleFrom = [
        "127.0.0.1/32"
        "${ if cfg.hostSubnet.ipv4 != "" then "${cfg.hostSubnet.ipv4}.0/24" else ""}"
        "${ if cfg.hostSubnet.ipv6 != "" then "${cfg.hostSubnet.ipv6}::/64" else ""}"
      ];
      portMappings = mkForwardPorts cfg.services;
      openVPNPorts = mkOpenPorts cfg.services;
    };

    systemd.services = createConfinementServices cfg.services;
  };
}