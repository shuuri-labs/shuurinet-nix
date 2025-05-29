{ inputs ? {} }:
let
  common = import ./common.nix;

  hostName = "shuurinet-router-bln";

  lanBridge = common.mkBridge [ "eth0" "eth1" "eth2" "eth3" "eth4" ];

  lanBridgeVlans = common.mkBridgeVlans {
    trunkPorts = [ "eth2" "eth3" ];
    lanPorts   = [ "eth0" "eth4" ];
    appsPorts   = [ "eth1" ];
  };

  interfaces = common.mkInterfaces {
    hostAddress = 1;
    dnsAddress  = 1;
    setGateway  = true;
  }; 

  firewallZones      = common.firewallZones;
  firewallForwarding = common.firewallForwarding;

  wanPort = "eth5";

  # dnsIp = "192.168.11.1";
in {
  openwrt.berlin-router-config = {
    deploy.host = "192.168.11.1";

    deploy.sshConfig = {
      Port         = 22;
      IdentityFile = "~/.ssh/id_ed25519";
    };

    services = {
      qemu-ga.enable = true;
    };

    packages = [ 
      "htop" 
      "nano" 
      "tcpdump" 
      "pciutils"
    ];

    uci.sopsSecrets = "/home/ashley/shuurinet-nix/secrets/sops/openwrt.yaml";

    uci.retain = [ "dhcp" "dropbear" "firewall" "luci" "rpcd" "system" "ucitrack" "uhttpd" ];

    uci.settings = {
      network = {
        globals = [
          {
            ula_prefix = "fd8f:2e0e:4eed::/48";
          }
        ];

        device = [
          lanBridge
        ];

        "bridge-vlan" = lanBridgeVlans.bridge-vlan;

        interface = interfaces // {
          system = {
            system = [{
              hostname = hostName;
              timezone = "UTC";
            }];
          };

          wan = {
            device           = wanPort;
            proto            = "pppoe";
            username._secret = "pppoe.username";
            password._secret = "pppoe.password";
            ipv6             = "auto";
          };

          wan6 = {
            device     = wanPort;
            proto      = "dhcpv6";
            reqaddress = "try";
            reqprefix  = "auto";
          };
        };
      };
      
      firewall = {
        zone = firewallZones ++ [
          { name = "wan"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; masq = true; mtu_fix = true; network = [ "wan" "wan6" ]; }
        ];

        forwarding = firewallForwarding ++ 
        [
          { src = "lan";        dest = "wan"; }
          { src = "guest";      dest = "wan"; }
          { src = "iot";        dest = "wan"; }
          { src = "apps";       dest = "wan"; }
          { src = "management"; dest = "wan"; }
        ];

        rule = [
          { name = "allow_mdns"; src = "*"; src_port = "5353"; dest_port = "5353"; proto = "udp"; dest_ip = "224.0.0.251"; target = "ACCEPT"; }

          { name = "guest_dns_dhcp";      src = "guest";      dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "iot_dns_dhcp";        src = "iot";        dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "apps_dns_dhcp";       src = "apps";       dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "management_dns_dhcp"; src = "management"; dest_port = "53 67 68"; target = "ACCEPT"; }

          # { name = "guest_adguard_dns";      src = "guest";      dest = "lan"; dest_port = "53"; dest_ip = dnsIp; target = "ACCEPT"; }
          # { name = "iot_adguard_dns";        src = "iot";        dest = "lan"; dest_port = "53"; dest_ip = dnsIp; target = "ACCEPT"; }
          # { name = "dmz_adguard_dns";        src = "apps";       dest = "lan"; dest_port = "53"; dest_ip = dnsIp; target = "ACCEPT"; }
          # { name = "management_adguard_dns"; src = "management"; dest = "lan"; dest_port = "53"; dest_ip = dnsIp; target = "ACCEPT"; }
          
          { name = "avr_block_forward";                src = "iot"; src_ip._secret = "host.avr.ip"; dest = "*"; target = "REJECT"; }
          { name = "living_room_switch_block_forward"; src = "lan"; src_ip = "192.168.11.5";        dest = "*"; target = "REJECT"; }
          { name = "kitchen_led_mqtt";                 src = "iot"; src_ip = "10.10.33.194";        dest = "lan"; dest_ip = "192.168.11.127"; dest_port = "1883"; target = "ACCEPT"; }
          { name = "tv_allow_airplay";                 src = "iot"; src_ip._secret = "host.tv.ip";  dest = "lan"; dest_port = "6002 7000 49152-65535"; target = "ACCEPT"; }
          { name = "living_room_switch_block_input";   src = "lan"; src_ip = "192.168.11.5";        target = "REJECT"; }

          # { name = "apps_nb_router_allow_jellyfin"; src = "apps"; src_ip._secret = "host.nbApps.ip"; dest = "lan"; dest_port = "8096"; dest_ip = "192.168.11.10"; target = "ACCEPT"; }
        ];
      };

      dhcp = {
        dnsmasq = [
          {
            domainneeded      = true;
            localise_queries  = true;
            rebind_protection = true;
            rebind_localhost  = true;
            local             = "/lan/";
            domain            = "lan";
            expandhosts       = true;
            cachesize         = 1000;
            authoritative     = true;
            readethers        = true;
            leasefile         = "/tmp/dhcp.leases";
            resolvfile        = "/tmp/resolv.conf.d/resolv.conf.auto";
            localservice      = true;
            ednspacket_max    = 1232;
          }
        ];

        dhcp = {
          lan = {
            interface = "lan";
            start     = 100;
            limit     = 150;
            leasetime = "12h";
            dhcpv4    = "server";
            ra        = "server";
            dhcpv6    = "server";
            ra_flags  = [ "managed-config" "other-config" ];
          };

          wan = {
            interface = "wan";
            ignore    = true;
          };

          guest = {
            interface = "guest";
            start     = 100;
            limit     = 150;
            leasetime = "12h";
          };

          iot = {
            interface = "iot";
            start     = 100;
            limit     = 150;
            leasetime = "12h";
          };

          apps = {
            interface = "apps";
            start     = 100;
            limit     = 150;
            leasetime = "12h";
            ra        = "server";
            dhcpv6    = "server";
          };

          management = {
            interface = "management";
            start     = 100;
            limit     = 150;
            leasetime = "12h";
          };
        };

        host = [
          # {
          #   name = "DNS";
          #   ip = "host.dns.ip";
          #   mac = "host.dns.mac";
          # }
          # {
          #   name = "DNS";
          #   duid = "host.dns.duid";
          #   mac = "host.dns.mac";
          # }
          {
            name._secret = "host.tv.name";
            ip._secret   = "host.tv.ip";
            mac._secret  = "host.tv.mac";
          }
          {
            name._secret = "host.avr.name";
            ip._secret   = "host.avr.ip";
            mac._secret  = "host.avr.mac";
          }
          {
            name._secret = "host.zigbee.name";
            ip._secret   = "host.zigbee.ip";
            mac._secret  = "host.zigbee.mac";
          }
          {
            name._secret = "host.kodi.name";
            ip._secret   = "host.kodi.ip";
            mac._secret  = "host.kodi.mac";
          }
        ];
      };

      sqm = {
        queue = {
          "${wanPort}" = {
            enabled = true;
            interface = wanPort;
            download = 178000;
            upload = 44000;
            qdisc = "cake";
            script = "piece_of_cake.qos";
            linklayer = "ethernet";
            debug_logging = false;
            verbosity = 5;
            overhead = 34;
          };
        };
      };
    };
    
    etc."avahi/avahi-daemon.conf".text = ''
      [server]
      use-ipv4=yes
      use-ipv6=yes
      check-response-ttl=no
      use-iff-running=no

      [publish]
      publish-addresses=yes
      publish-hinfo=yes
      publish-workstation=no
      publish-domain=yes

      [reflector]
      enable-reflector=yes
      reflect-ipv=no

      [rlimits]
      rlimit-core=0
      rlimit-data=4194304
      rlimit-fsize=0
      rlimit-nofile=30
      rlimit-stack=4194304
      rlimit-nproc=3
    '';
  };
}

# nix build .#berlin-router-config --show-trace
# sudo -E ./result/bin/deploy-berlin-router-config 