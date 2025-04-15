{
  openwrt.vm-test-router-config = {
    deploy.host = "192.168.11.51";

    deploy.sshConfig = {
      Port = 22;
      IdentityFile = "~/.ssh/id_ed25519";
    };

    services = {
      qemu-ga.enable = true;
    };

    packages = [ 
      "htop" 
      "nano" 
      "tcpdump" 
      "kmod-mlx5-core" 
    ];

    uci.sopsSecrets = "/home/ashley/shuurinet-nix/secrets/sops/openwrt.yaml";

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
            ipaddr = "192.168.11.51";
            gateway = "192.168.11.1";
            netmask = "255.255.255.0";
            ip6assign = "60";
            dns = [ "192.168.11.1" ];
          };

          guest = {
            proto = "static";
            device = "br-lan.22";
            ipaddr = "10.10.23.1";
            netmask = "255.255.255.0";
            dns._secret = "host.dns.ipList";
          };

          iot = {
            proto = "static";
            device = "br-lan.33";
            ipaddr = "10.10.34.1";
            netmask = "255.255.255.0";
            dns._secret = "host.dns.ipList";
          };

          apps = {
            proto = "static";
            device = "br-lan.44";
            ipaddr = "10.10.45.1";
            netmask = "255.255.255.0";
            dns._secret = "host.dns.ipList";
          };

          wan = {
            device = "eth2";
            proto = "pppoe";
            username._secret = "pppoe.username";
            password._secret = "pppoe.password";
            ipv6 = "auto";
          };

          wan6 = {
            device = "eth2";
            proto = "dhcpv6";
            reqaddress = "try";
            reqprefix = "auto";
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
          { src = "lan"; dest = "iot"; }
          { src = "lan"; dest = "apps"; }
          { src = "guest"; dest = "wan"; }
          { src = "iot"; dest = "wan"; }
          { src = "apps"; dest = "wan"; }
        ];

        rule = [
          { name = "guest_dns_dhcp"; src = "guest"; dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "iot_dns_dhcp"; src = "iot"; dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "apps_dns_dhcp"; src = "apps"; dest_port = "53 67 68"; target = "ACCEPT"; }
          { name = "avr_block_forward"; src = "iot"; src_ip._secret = "host.avr.ip"; dest = "*"; target = "REJECT"; }
          { name = "living_room_switch_block_forward"; src = "lan"; src_ip = "192.168.11.5"; dest = "*"; target = "REJECT"; }
          { name = "living_room_switch_block_input"; src = "lan"; src_ip = "192.168.11.5"; target = "REJECT"; }
          { name = "kitchen_led_mqtt"; src = "iot"; src_ip = "10.10.33.194"; dest = "lan"; dest_ip = "192.168.11.127"; dest_port = "1883"; target = "ACCEPT"; }
          { name = "allow_mdns"; src = "*"; src_port = "5353"; dest_port = "5353"; proto = "udp"; dest_ip = "224.0.0.251"; target = "ACCEPT"; }
          { name = "guest_adguard_dns"; src = "guest"; dest = "lan"; dest_port = "53"; dest_ip._secret = "host.dns.ipList"; target = "ACCEPT"; }
          { name = "iot_adguard_dns"; src = "iot"; dest = "lan"; dest_port = "53"; dest_ip._secret = "host.dns.ipList"; target = "ACCEPT"; }
          { name = "dmz_adguard_dns"; src = "apps"; dest = "lan"; dest_port = "53"; dest_ip._secret = "host.dns.ipList"; target = "ACCEPT"; }
          { name = "apps_nb_router_allow_jellyfin"; src = "apps"; src_ip._secret = "host.nbApps.ip"; dest = "lan"; dest_port = "8096"; dest_ip = "192.168.11.10"; target = "ACCEPT"; }
          { name = "tv_allow_airplay"; src = "iot"; src_ip._secret = "host.tv.ip"; dest = "lan"; dest_port = "6002 7000 49152-65535"; target = "ACCEPT"; }
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
            name = "DNS";
            ip._secret = "host.dns.ip";
            mac._secret = "host.dns.mac";
          }
          {
            name = "DNS";
            duid._secret = "host.dns.duid";
            mac._secret = "host.dns.mac";
          }
          {
            name._secret = "host.tv.name";
            ip._secret = "host.tv.ip";
            mac._secret = "host.tv.mac";
          }
          {
            name._secret = "host.avr.name";
            ip._secret = "host.avr.ip";
            mac._secret = "host.avr.mac";
          }
          {
            name._secret = "host.zigbee.name";
            ip._secret = "host.zigbee.ip";
            mac._secret = "host.zigbee.mac";
          }
          {
            name._secret = "host.kodi.name";
            ip._secret = "host.kodi.ip";
            mac._secret = "host.kodi.mac";
          }
        ];
      };

      sqm = {
        queue = {
          eth1 = {
            enabled = true;
            interface = "eth1";
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
      #host-name=foo
      #domain-name=local
      use-ipv4=yes
      use-ipv6=yes
      check-response-ttl=no
      use-iff-running=no

      [publish]
      publish-addresses=yes
      publish-hinfo=yes
      publish-workstation=no
      publish-domain=yes
      #publish-dns-servers=192.168.11.1
      #publish-resolv-conf-dns-servers=yes

      [reflector]
      enable-reflector=yes
      reflect-ipv=no

      [rlimits]
      #rlimit-as=
      rlimit-core=0
      rlimit-data=4194304
      rlimit-fsize=0
      rlimit-nofile=30
      rlimit-stack=4194304
      rlimit-nproc=3
    '';
  };
}

# nix build .#vm-test-router-config --show-trace
# sudo -E ./result/bin/deploy-vm-test-router-config 