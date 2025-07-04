{ lib, name, dnsRecords ? [], staticLeases ? {}, ... }:
let
  isRouter = false;
  hostAddress = 51;
  dnsAddresses = [ "192.168.1.1" ];

  bridgePorts = [ "eth0" "eth1" "eth2" "eth3" "eth4" ];
  trunkPorts = [ "eth2" "eth3" ];
  wanPort = "eth5";

  interfaces = {
    lan = {
      vlanId = 11;
      ports = [ "eth0" "eth2" ];
      trunkPorts = trunkPorts;
      address = {
        prefix = "192.168.11";
      };
      forwards = [ "*" ];
      isPrivileged = true;
      isPrimary = true;
    };

    guest = {
      vlanId = 22;
      trunkPorts = trunkPorts;
      address = {
        prefix = "10.10.22";
      };
    };

    iot = {
      vlanId = 33;
      trunkPorts = trunkPorts;
      address = {
        prefix = "10.10.33";
      };
    };

    apps = {
      vlanId = 44;
      trunkPorts = trunkPorts;
      address = {
        prefix = "10.10.44";
      };
    };

    management = {
      vlanId = 55;
      ports = [ "eth3" ];
      trunkPorts = trunkPorts;
      address = {
        prefix = "10.10.55";
      };
      isPrivileged = true;
    };
  };

  helper = import /home/ashley/shuurinet-nix/homelab/services/openwrt/config/helper.nix { inherit lib isRouter dnsAddresses; };
in
{
  config = {
    openwrt.${name} = {
      deploy = {
        host = interfaces.lan.address.prefix + "." + toString hostAddress;

        sshConfig = {
          Port         = 22;
          IdentityFile = "~/.ssh/id_ed25519";
        };
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

      uci.retain = [ /* "dhcp" */ "dropbear" /* "firewall" */ "luci" "rpcd" "ucitrack" "uhttpd" ];

      uci.settings = {
        system = {
          system = [{
            hostname = name;
            timezone = "UTC";
          }];
        };

        network = {
          globals = [
            {
              ula_prefix = "fd0b:b19b:f355::/48";
            }
          ];

          device = [
            {
              name = "br-lan";
              type = "bridge";
              ports = bridgePorts;
            }
          ];

          "bridge-vlan" = helper.mkBridgeVlans {
            inherit interfaces;
          };

          interface = helper.mkInterfaces {
            inherit interfaces hostAddress;
          };
        };

        firewall = helper.mkFirewall {
          inherit interfaces;
          extraRules = [
            { name = "avr_block_forward";                src = "iot"; src_ip = "${interfaces.iot.address.prefix}.118"; dest = "*"; target = "REJECT"; }
            { name = "living_room_switch_block_forward"; src = "lan"; src_ip = "${interfaces.lan.address.prefix}.5"; dest = "*"; target = "REJECT"; }
            # { name = "kitchen_led_mqtt";                 src = "iot"; src_ip = "${interfaces.iot.address.prefix}.194"; dest = "lan"; dest_ip = "${interfaces.lan.address.prefix}.127"; dest_port = "1883"; target = "ACCEPT"; }
            { name = "tv_allow_airplay";                 src = "iot"; src_ip = "${interfaces.iot.address.prefix}.192";  dest = "lan"; dest_port = "6002 7000 49152-65535"; target = "ACCEPT"; }
            { name = "living_room_switch_block_input";   src = "lan"; src_ip = "${interfaces.lan.address.prefix}.5"; target = "REJECT"; }
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

          dhcp = helper.mkDHCP {
            inherit interfaces;
          };

          domain = dnsRecords;
          host = staticLeases;
        };

        # sqm = helper.mkSQM {
        #   inherit wanPort;
        #   download = 900000;
        #   upload = 51000;
        # };

        # etc."avahi/avahi-daemon.conf".text = ''
        #   [server]
        #   use-ipv4=no
        #   use-ipv6=no
        #   check-response-ttl=no
        #   use-iff-running=no

        #   [publish]
        #   publish-addresses=no
        #   publish-hinfo=no
        #   publish-workstation=no
        #   publish-domain=no

        #   [reflector]
        #   enable-reflector=no
        #   reflect-ipv=no

        #   [rlimits]
        #   rlimit-core=0
        #   rlimit-data=4194304
        #   rlimit-fsize=0
        #   rlimit-nofile=30
        #   rlimit-stack=4194304
        #   rlimit-nproc=3
        # '';
      };
    };
  };
}