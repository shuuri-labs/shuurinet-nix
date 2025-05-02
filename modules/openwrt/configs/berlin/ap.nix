let
  common = import ./common.nix;
  
  interfaces = common.mkInterfaces 
    "192.168.11.1"  # dns
    "192.168.11.2" # lanIp
    "10.10.23.2"    # guestIp
    "10.10.34.2"    # iotIp
    "10.10.45.2"    # appsIp
    "10.10.56.2";   # managementIp
in {
  openwrt.berlin-ap-config = {
    deploy.host = "192.168.11.3";

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
    ];

    uci.sopsSecrets = "/home/ashley/shuurinet-nix/secrets/sops/openwrt.yaml";

    uci.retain = [ "dhcp" "dropbear" "firewall" "luci" "rpcd" "system" "ucitrack" "uhttpd" ];

    uci.settings = {
      network = {
        globals = [
          {
            ula_prefix = "fd0b:e404:9217::/48";
          }
        ];

        device = [
          {
            name = "br-lan";
            type = "bridge";
            ports = [ "eth0" "eth1" "eth2" ];
          }
        ];

        "bridge-vlan" = [
          {
            device = "br-lan";
            vlan = "11";
            ports = [ "eth0:t*" "eth1:t" "eth2:t" ];
          }
          {
            device = "br-lan";
            vlan = "22";
            ports = [ "eth0:t" "eth1:t" "eth2:t" ];
          }
          {
            device = "br-lan";
            vlan = "33";
            ports = [ "eth0:t" "eth1:t" "eth2:t" ];
          }
          {
            device = "br-lan";
            vlan = "44";
            ports = [ "eth0:t" "eth1:t" "eth2:t" ];
          }
        ];

        interface = interfaces;
      };

      wifi = {
        wifi-device = {
          radio0 = {
            type = "mac80211";
            phy = "wl0";
            country = "DE";
            cell_density = "0";
          };

          radio1 = {
            type = "mac80211";
            phy = "wl1";
            country = "DE";
            cell_density = "0";
            htmode = "HE80";
            band = "5g";
            channel = "52";
          };
        };
        
        wifi-iface = {
          lan_5ghz = {
            device = "radio1";
            mode = "ap";
            ssid._secret = "iface.lan.ssid.5ghz";
            encryption = "sae";
            key._secret = "iface.lan.key";
            network = "lan";
          };

          lan_24ghz = {
            device = "radio0";
            mode = "ap";
            ssid._secret = "iface.lan.ssid.24ghz";
            encryption = "sae";
            key._secret = "iface.lan.key";
            network = "lan";
            disabled = true;
          };

          guest_5ghz = {
            device = "radio1";
            network = "guest";
            mode = "ap";
            ssid._secret = "iface.guest.ssid.5ghz";
            encryption = "psk2";
            key._secret = "iface.guest.key";
          };

          guest_24ghz = {
            device = "radio0";
            mode = "ap";
            ssid._secret = "iface.guest.ssid.24ghz";
            encryption = "psk2";
            key._secret = "iface.guest.key";
            network = "guest";
            disabled = true;
          };

          iot_24ghz = {
            device = "radio0";
            network = "iot";
            mode = "ap";
            ssid._secret = "iface.iot.ssid.24ghz";
            encryption = "psk2";
            key._secret = "iface.iot.key";
          };
        };
      };
      
      $(import ./firewall.nix)
    };
  };
}

# nix build .#berlin-router-config --show-trace
# sudo -E ./result/bin/deploy-berlin-router-config 