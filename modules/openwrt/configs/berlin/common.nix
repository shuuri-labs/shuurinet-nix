let
  lanSubnet        = "192.168.11";
  guestSubnet      = "10.10.22";
  iotSubnet        = "10.10.33";
  appsSubnet       = "10.10.44";
  managementSubnet = "10.10.55";

  /* ============================================================================== */
  /* =========================== Bridge Helper Functions ========================== */
  /* ============================================================================== */

  mkBridge = ports: 
    {
      name   = "br-lan";
      type   = "bridge";
      ports  = ports;
    };

  /* =================================================================================== */
  /* =========================== Bridge VLAN Helper Functions ========================== */
  /* =================================================================================== */

  portsFormatted = interfacePorts: trunkPorts:
    map (port: "${port}:u*") interfacePorts ++ 
    map (port: "${port}:t") (builtins.filter (port: !(builtins.elem port interfacePorts)) trunkPorts);

  mkBridgeVlans = {
    trunkPorts      ? [],
    lanPorts        ? [],
    guestPorts      ? [],
    iotPorts        ? [],
    appsPorts       ? [],
    managementPorts ? []
  }: {
    "bridge-vlan" = [
      {
      # lan
      device   = "br-lan";
        vlan   = "11";
        ports  = portsFormatted lanPorts trunkPorts;
      }
      # guest
      {
        device = "br-lan";
        vlan   = "22";
        ports  = portsFormatted guestPorts trunkPorts;
      }
      # iot
      {
        device = "br-lan";
        vlan   = "33";
        ports  = portsFormatted iotPorts trunkPorts;
      }
      # apps
      {
        device = "br-lan";
        vlan   = "44";
        ports  = portsFormatted appsPorts trunkPorts;
      }
      # management
      {
        device = "br-lan";
        vlan   = "55";
        ports  = portsFormatted managementPorts trunkPorts;
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

  mkGateway = 
    setGateway: 
    subnet: 
      if setGateway then "${subnet}.1" else "";
  
  mkInterfaces = {
    hostAddress,
    dnsAddress ? null,
    setGateway ? false
  }: {
    loopback = {
      device  = "lo";
      proto   = "static";
      ipaddr  = "127.0.0.1";
      netmask = "255.0.0.0";
    };
        
    lan = {
      device  = "br-lan.11";
      proto   = "static";
      ipaddr  = mkAddress lanSubnet hostAddress;
      netmask = "255.255.255.0";
      dns     = mkDns dnsAddress;
      gateway = mkGateway setGateway lanSubnet;
      metric  = 10;
    };

    guest = {
      device  = "br-lan.22";
      proto   = "static";
      ipaddr  = mkAddress guestSubnet hostAddress;
      netmask = "255.255.255.0";
      dns     = mkDns dnsAddress;
      gateway = mkGateway setGateway guestSubnet;
      metric  = 100;
    };

    iot = {
      device  = "br-lan.33";
      proto   = "static";
      ipaddr  = mkAddress iotSubnet hostAddress;
      netmask = "255.255.255.0";
      dns     = mkDns dnsAddress;
      gateway = mkGateway setGateway iotSubnet;
      metric  = 100;
    };

    apps = {
      device  = "br-lan.44";
      proto   = "static";
      ipaddr  = mkAddress appsSubnet hostAddress;
      netmask = "255.255.255.0";
      dns     = mkDns dnsAddress;
      gateway = mkGateway setGateway appsSubnet;
      metric  = 100;
    };

    management = {
      device  = "br-lan.55";
      proto   = "static";
      ipaddr  = mkAddress managementSubnet hostAddress;
      netmask = "255.255.255.0";
      dns     = mkDns dnsAddress;
      gateway = mkGateway setGateway managementSubnet;
      metric  = 100;
    };
  };
in 
{
  firewallZones = [
    { name = "lan";        input = "ACCEPT"; output = "ACCEPT"; forward = "ACCEPT"; network = [ "lan" ]; }
    { name = "guest";      input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "guest" ]; }
    { name = "iot";        input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "iot" ]; }
    { name = "apps";       input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "apps" ]; }
    { name = "management"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "management" ]; }
  ];

  firewallForwarding = [
    { src = "lan"; dest = "guest"; }
    { src = "lan"; dest = "iot"; }
    { src = "lan"; dest = "apps"; }
    { src = "lan"; dest = "management"; }
  ];

  inherit mkBridge mkBridgeVlans mkInterfaces;
}

# nix build .#berlin-router-config --show-trace
# sudo -E ./result/bin/deploy-berlin-router-config 