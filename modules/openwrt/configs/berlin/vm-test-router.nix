{ pkgs, ... }:
let
  sqmConfigFile = pkgs.writeText "sqm.apk-new" ''
    config queue 'eth1'
    	option interface 'eth2'
    	option enabled '1'
    	option download '178000'
    	option upload '44000'
    	option qdisc 'cake'
    	option script 'piece_of_cake.qos'
    	option linklayer 'ethernet'
    	option overhead '34'
    	option debug_logging '0'
    	option verbosity '5'
  '';
in
{
  openwrt.vm-test-router = {
    deploy.host = "192.168.11.132";
    deploy.sshConfig = {
      Port = 22;
      IdentityFile = "/home/ashley/.ssh/id_ed25519";
    };

    deploySteps.sqmConfig = {
      priority = 50;
      copy = ''
        echo "Copying sqm config..."
        scp ${sqmConfigFile} device:/tmp/sqm.apk-new
        ssh 'mv /tmp/sqm.apk-new /etc/config/sqm.apk-new'
      '';
      apply = ''
        echo "Nothing to apply for sqm config"
      '';
    };

    services = {
      qemu-ga.enable = true;
    };

    uci.retain = [ "dhcp" "dropbear" "firewall" "luci" "rpcd" "system" "ucitrack" "uhttpd" ];

    uci.settings = {
      network = {
        globals = [
          {
            ula_prefix = "fdbb:25f1:9e8a::/48";
          }
        ];

        device = [
          {
            name = "br-lan";
            type = "bridge";
            ports = [ "eth0" "eth1" ];
          }
        ];

        "bridge-vlan" = [
          {
            device = "br-lan";
            vlan = "11";
            ports = [ "eth0:u*" "eth1:t" ];
          }
          {
            device = "br-lan";
            vlan = "22";
            ports = [ "eth1:t" ];
          }
          {
            device = "br-lan";
            vlan = "33";
            ports = [ "eth0:t" "eth1:t" ];
          }
          {
            device = "br-lan";
            vlan = "44";
            ports = [ "eth0:t" ];
          }
        ];

        interface = {
          loopback = {
            device = "lo";
            proto = "static";
            ipaddr = "127.0.0.1";
            netmask = "255.0.0.0";
          };

          lan = {
            device = "br-lan.11";
            proto = "static";
            ipaddr = "192.168.11.132";
            gateway = "192.168.11.1";
            netmask = "255.255.255.0";
            ip6assign = "60";
            dns = [ "192.168.11.1" ];
          };

          wan = {
            device = "eth2";
            proto = "pppoe";
            username = "DSL00038009@s93.bbi-o2.de";
            password = "tg37kkgg";
            ipv6 = "auto";
          };

          wan6 = {
            device = "eth2";
            proto = "dhcpv6";
            reqaddress = "try";
            reqprefix = "auto";
          };

          guest = {
            proto = "static";
            device = "br-lan.22";
            ipaddr = "10.10.23.1";
            netmask = "255.255.255.0";
            dns = [ "fd8f:2e0e:4eed::3ee" "192.168.11.136" ];
          };

          iot = {
            proto = "static";
            device = "br-lan.33";
            ipaddr = "10.10.34.1";
            netmask = "255.255.255.0";
            dns = [ "fd8f:2e0e:4eed::3ee" "192.168.11.136" ];
          };

          apps = {
            proto = "static";
            device = "br-lan.44";
            ipaddr = "10.10.45.1";
            netmask = "255.255.255.0";
            dns = [ "192.168.11.136" "fd8f:2e0e:4eed::3ee" ];
          };
        };
      };
      
      firewall = {
        zone = [
          { name = "lan"; input = "ACCEPT"; output = "ACCEPT"; forward = "ACCEPT"; network = [ "lan" ]; }
          { name = "wan"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; masq = true; mtu_fix = true; network = [ "wan" "wan6" ]; }
          { name = "guest"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "guest" ]; }
          { name = "iot"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "iot" ]; }
          { name = "apps"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "apps" ]; }
        ];

        forwarding = [
          { src = "lan"; dest = "wan"; }
          { src = "guest"; dest = "wan"; }
          { src = "iot"; dest = "wan"; }
          { src = "apps"; dest = "wan"; }
          { src = "lan"; dest = "iot"; }
          { src = "lan"; dest = "apps"; }
        ];

        rule = [
          { name = "guest_dns_dhcp"; src = "guest"; dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "iot_dns_dhcp"; src = "iot"; dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "apps_dns_dhcp"; src = "apps"; dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "marantz_block_forward"; src = "iot"; src_ip = "10.10.33.118"; dest = "*"; target = "REJECT"; }
          { name = "kodi_allow_jellyfin"; src = "iot"; src_ip = "10.10.33.162"; dest = "lan"; dest_port = "8096"; dest_ip = "192.168.11.10"; target = "ACCEPT"; }
          { name = "kodi_allow_smb"; src = "iot"; src_ip = "10.10.33.162"; dest = "lan"; dest_port = "139 445"; dest_ip = "192.168.11.19"; target = "ACCEPT"; }
          { name = "switch_block_forward"; src = "lan"; src_ip = "192.168.11.199"; dest = "*"; target = "REJECT"; }
          { name = "switch_block_input"; src = "lan"; src_ip = "192.168.11.199"; target = "REJECT"; }
          { name = "kitchen_led_mqtt"; src = "iot"; src_ip = "10.10.33.194"; dest = "lan"; dest_ip = "192.168.11.127"; dest_port = "1883"; target = "ACCEPT"; }
          { name = "allow_mdns"; src = "*"; src_port = "5353"; dest_port = "5353"; proto = "udp"; dest_ip = "224.0.0.251"; target = "ACCEPT"; }
          { name = "guest_adguard_dns"; src = "guest"; dest = "lan"; dest_port = "53"; dest_ip = [ "192.168.11.136" "fd8f:2e0e:4eed::3ee" ]; target = "ACCEPT"; }
          { name = "iot_adguard_dns"; src = "iot"; dest = "lan"; dest_port = "53"; dest_ip = [ "192.168.11.136" "fd8f:2e0e:4eed::3ee" ]; target = "ACCEPT"; }
          { name = "dmz_adguard_dns"; src = "apps"; dest = "lan"; dest_port = "53"; dest_ip = [ "192.168.11.136" "fd8f:2e0e:4eed::3ee" ]; target = "ACCEPT"; }
          { name = "apps_allow_jellyfin"; src = "apps"; src_ip = "10.10.44.2"; dest = "lan"; dest_port = "8096"; dest_ip = "192.168.11.10"; target = "ACCEPT"; }
          { name = "lg_tv_allow_airplay"; src = "iot"; src_ip = "10.10.33.192"; dest = "lan"; dest_port = "6002 7000 49152-65535"; target = "ACCEPT"; }
        ];
      };

      dhcp = {
        dnsmasq = [
          {
            domainneeded = true;
            localise_queries = true;
            rebind_protection = true;
            rebind_localhost = true;
            local = "/lan/";
            domain = "lan";
            expandhosts = true;
            cachesize = 1000;
            authoritative = true;
            readethers = true;
            leasefile = "/tmp/dhcp.leases";
            resolvfile = "/tmp/resolv.conf.d/resolv.conf.auto";
            localservice = true;
            ednspacket_max = 1232;
          }
        ];

        dhcp = {
          lan = {
            interface = "lan";
            start = 100;
            limit = 150;
            leasetime = "12h";
            dhcpv4 = "server";
            ra = "server";
            dhcpv6 = "server";
            ra_flags = [ "managed-config" "other-config" ];
          };

          wan = {
            interface = "wan";
            ignore = true;
          };

          guest = {
            interface = "guest";
            start = 100;
            limit = 150;
            leasetime = "12h";
          };

          iot = {
            interface = "iot";
            start = 100;
            limit = 150;
            leasetime = "12h";
          };

          apps = {
            interface = "apps";
            start = 100;
            limit = 150;
            leasetime = "12h";
            ra = "server";
            dhcpv6 = "server";
          };
        };

        host = [
          {
            name = "Marantz-AV7005";
            ip = "10.10.33.118";
            mac = [ "00:06:78:08:1B:45" ];
          }
          {
            name = "dns";
            ip = "192.168.11.135";
            mac = [ "BC:24:11:38:30:7B" ];
          }
          {
            name = "dns";
            duid = "000100012DC63879BC241138307A";
            mac = [ "BC:24:11:38:30:7B" ];
          }
          {
            name = "LGwebOSTV";
            ip = "10.10.33.192";
            mac = [ "74:C1:7E:6E:31:09" ];
          }
          {
            name = "SLZB-06";
            ip = "10.10.33.154";
            mac = [ "14:2B:2F:D9:CC:24" ];
          }
          {
            name = "Kodi-living-room";
            ip = "192.168.11.162";
            mac = [ "90:0E:B3:FD:5A:3D" ];
          }
        ];
      };

      sqm = {
        eth1 = {
          main = {
            enabled = true;
            interface = "eth2";
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
  };
}


# nix build .#vm-test-router --show-trace