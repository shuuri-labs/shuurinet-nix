let
  lanSubnet = "192.168.11";

  /* ============================================================================== */
  /* =========================== Bridge Helper Functions ========================== */
  /* ============================================================================== */

  mkBridge = ports: 
    {
      device = "br-lan";
      type = "bridge";
      ports = ports;
    };

  /* =================================================================================== */
  /* =========================== Bridge VLAN Helper Functions ========================== */
  /* =================================================================================== */

  interfacePortsFormatted = interfacePorts:
    map (port: "${port}:u*") interfacePorts;

  trunkPortsFormatted = trunkPorts: interfacePorts:
    map (port: "${port}:t") (builtins.filter (port: !(builtins.elem port interfacePorts)) trunkPorts);

  portsFormatted = interfacePorts: trunkPorts:
    interfacePortsFormatted interfacePorts ++ trunkPortsFormatted trunkPorts interfacePorts;

  mkBridgeVlans = {
    trunkPorts      ? [],
    lanPorts        ? [],
    guestPorts      ? [],
    iotPorts        ? [],
    appsPorts       ? [],
    managementPorts ? []
  }: {
    "bridge_vlan" = [
      {
      # lan
      device = "br-lan";
        vlan = "11";
        ports = portsFormatted lanPorts trunkPorts;
      }
      # guest
      {
        device = "br-lan";
        vlan = "22";
        ports = portsFormatted guestPorts trunkPorts;
      }
      # iot
      {
        device = "br-lan";
        vlan = "33";
        ports = portsFormatted iotPorts trunkPorts;
      }
      # apps
      {
        device = "br-lan";
        vlan = "44";
        ports = portsFormatted appsPorts trunkPorts;
      }
      # management
      {
        device = "br-lan";
        vlan = "55";
        ports = portsFormatted managementPorts trunkPorts;
      }
    ];
  };

  /* =================================================================================== */
  /* =========================== Interface Helper Functions ============================ */
  /* =================================================================================== */

  mkAddress = subnet: 
    address: subnet + "." + toString address;
  mkDns = address: 
    if address != null then [ "${lanSubnet}.${toString address}" ] else [];
  
  mkInterfaces = {
    hostAddress,
    dnsAddress ? null,
  }: {
    loopback = {
      device = "lo";
      proto = "static";
      ipaddr = "127.0.0.1";
      netmask = "255.0.0.0";
    };
        
    lan = {
      device = "br-lan.11";
      proto = "static";
      ipaddr = mkAddress lanSubnet hostAddress;
      netmask = "255.255.255.0";
      dns = mkDns dnsAddress;
    };

    guest = {
      device = "br-lan.22";
      proto = "static";
      ipaddr = mkAddress "10.10.22" hostAddress;
      netmask = "255.255.255.0";
      dns = mkDns dnsAddress;
    };

    iot = {
      device = "br-lan.33";
      proto = "static";
      ipaddr = mkAddress "10.10.33" hostAddress;
      netmask = "255.255.255.0";
      dns = mkDns dnsAddress;
    };

    apps = {
      device = "br-lan.44";
      proto = "static";
      ipaddr = mkAddress "10.10.44" hostAddress;
      netmask = "255.255.255.0";
      dns = mkDns dnsAddress;
    };

    management = {
      device = "br-lan.55";
      proto = "static";
      ipaddr = mkAddress "10.10.55" hostAddress;
      netmask = "255.255.255.0";
      dns = mkDns dnsAddress;
    };
  };
in 
{
  firewallZones = [
    { name = "lan"; input = "ACCEPT"; output = "ACCEPT"; forward = "ACCEPT"; network = [ "lan" ]; }
    { name = "guest"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "guest" ]; }
    { name = "iot"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "iot" ]; }
    { name = "apps"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "apps" ]; }
    { name = "management"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "management" ]; }
  ];

  firewallForwarding = [
    { src = "lan"; dest = "wan"; }
    { src = "lan"; dest = "guest"; }
    { src = "lan"; dest = "iot"; }
    { src = "lan"; dest = "apps"; }
    { src = "lan"; dest = "management"; }
  ];

  inherit mkBridge mkBridgeVlans mkInterfaces;
}

# nix build .#berlin-router-config --show-trace
# sudo -E ./result/bin/deploy-berlin-router-config 