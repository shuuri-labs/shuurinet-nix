{ lib, isRouter ? false, dnsAddresses ? [], ... }:
let 
  # ------------------------------ Helper Functions ------------------------------

  formatPorts = interfacePorts: trunkPorts:
    map (port: "${port}:u*") interfacePorts ++ 
    map (port: "${port}:t") (builtins.filter (port: !(builtins.elem port interfacePorts)) trunkPorts);

  formatAddress = { subnet, lastOctet }: 
    subnet + "." + toString lastOctet;

  # Filter DNS addresses to get only the first IPv4 address found
  dnsAddressIpv4 = lib.findFirst 
    (addr: lib.hasInfix "." addr && !lib.hasInfix ":" addr) 
    null 
    dnsAddresses;

  # ------------------------------ Bridge VLANs ------------------------------

  mkBridgeVlans = { 
    interfaces,
    ...
  }: lib.mapAttrsToList (name: interface: {
    device = "br-lan";  
    vlan = toString interface.vlanId;
    ports = formatPorts interface.ports interface.trunkPorts;
  }) interfaces; 

  # ------------------------------ Interfaces ------------------------------

  mkInterfaces = 
  let
    proto = "static";
    netmask = "255.255.255.0";
  in 
  {
    hostAddress,
    interfaces,
    pppoeUsername ? "",
    pppoePassword ? "",
    ...
  }: {
    loopback = {
      device  = "lo";
      proto   = "static";
      ipaddr  = "127.0.0.1";
      netmask = "255.0.0.0";
    };
  } // (lib.mapAttrs (name: interface: {
    device  = "br-lan.${toString interface.vlanId}";
    proto   = proto;
    ipaddr  = formatAddress { subnet = interface.address.prefix; lastOctet = hostAddress; };
    dns     = lib.concatStringsSep "," dnsAddresses;
    gateway = if !isRouter && interface.isPrimary then formatAddress { subnet = interface.address.prefix; lastOctet = 1; } else "";
    netmask = netmask;
    # metric = if interface.isPrimary then 10 else 100;
  }) interfaces) // {
    "wan" = lib.mkIf isRouter {
      device = "wan";
      proto = if pppoeUsername != null && pppoePassword != null then "pppoe" else "dhcp";
      username = pppoeUsername;
      password = pppoePassword;
      ipv6 = "auto";
    };
    "wan6" = lib.mkIf isRouter {
      device = "wan6";
      proto = "dhcpv6";
      reqaddress = "try";
      reqprefix = "auto";
    };
  };

  # ------------------------------ Firewall ------------------------------
  
  mkFirewall = {
    interfaces, 
    dnsZone ? "lan",
    extraRules ? [],
    ...
  }: {
    zone = lib.mapAttrsToList (name: interface: {
      name = name;
      input = if interface.isPrivileged then "ACCEPT" else "REJECT";
      output = "ACCEPT";
      forward = if interface.isPrivileged then "ACCEPT" else "REJECT";
      network = [ name ];
    }) interfaces ++ lib.optionals isRouter [
      { name = "wan"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "wan" "wan6" ]; }
    ];

    forwarding = lib.flatten (lib.mapAttrsToList (srcName: interface: 
      let
        # Get all interface names except the current source
        allOtherInterfaces = lib.filter (name: name != srcName) (lib.attrNames interfaces);
        
        # Determine target interfaces based on forwards field
        forwards = interface.forwards or [];
        targetInterfaces = 
          if builtins.elem "*" forwards then
            allOtherInterfaces ++ lib.optionals isRouter [ "wan" ]
          else
            # Remove duplicates in case "wan" is explicitly listed and isRouter is true
            lib.unique (forwards ++ lib.optionals isRouter [ "wan" ]);
      in
        # Create forwarding rules for each target
        map (destName: {
          src = srcName;
          dest = destName;
        }) targetInterfaces
    ) interfaces);

    rule = lib.flatten [
      # DNS/DHCP rules for each interface (only if router)
      (lib.optionals isRouter (lib.mapAttrsToList (name: interface: {
        name = "${name}_dns_dhcp";
        src = name;
        dest_port = "53 67 68";
        target = "ACCEPT";
      }) interfaces))
      
      # AdGuard DNS rules for each interface (only if is router and DNS address provided)
      (lib.optionals (isRouter && dnsAddressIpv4 != null) (lib.mapAttrsToList (name: interface: {
        name = "${name}_adguard_dns";
        src = name;
        dest = dnsZone;
        dest_port = "53";
        dest_ip = dnsAddressIpv4;
        target = "ACCEPT";
      }) interfaces))
      
      # mDNS rule (only if router)
      (lib.optionals isRouter [
        { name = "allow_mdns"; src = "*"; src_port = "5353"; dest_port = "5353"; proto = "udp"; dest_ip = "224.0.0.251"; target = "ACCEPT"; }
      ])
      
      # Extra custom rules
      extraRules
    ];
  };

  mkDHCP = {
    interfaces,
    ...
  }: lib.mapAttrs (name: interface: {
    interface = name;
    ignore = !isRouter;
  }) interfaces;

  mkSQM = {
    wanPort,
    download,
    upload,
    ...
  }: {
    sqm = {
      queue = {
        "${wanPort}" = {
          enabled = true;
          interface = wanPort;
          download = download;
          upload = upload;
          qdisc = "cake";
          script = "piece_of_cake.qos";
          linklayer = "ethernet";
          debug_logging = false;
          # verbosity = 5;
          # overhead = 34;
        };
      };
    };
  };
in 
{
  inherit mkBridgeVlans mkInterfaces mkFirewall mkDHCP mkSQM;
}