{ lib, name, dnsRecords ? [], staticLeases ? {}, ... }:
let
  isRouter = false;
  hostAddress = 51;
  dnsAddresses = [ "192.168.11.1" ];

  bridgePorts = [ "eth0" "eth1" "eth2" "eth3" "eth4" ];
  trunkPorts = [ "eth2" "eth3" ];
  wanPort = "eth5";

  # Define interfaces - these will be converted to interfaceType by the helper for type safety
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
      ports = [];  # VLAN-only interface, no direct ports
      trunkPorts = trunkPorts;
      address = {
        prefix = "10.10.22";
      };
    };

    iot = {
      vlanId = 33;
      ports = [];  # VLAN-only interface, no direct ports
      trunkPorts = trunkPorts;
      address = {
        prefix = "10.10.33";
      };
    };

    apps = {
      vlanId = 44;
      ports = [];  # VLAN-only interface, no direct ports
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
    };
  };

  helper = import /home/ashley/shuurinet-nix/homelab/lib/openwrt-config-autodeploy/helper.nix { inherit lib interfaces isRouter dnsAddresses; };
in
{
  config = {
    openwrt.${name} = {
      deploy = {
        host = interfaces.lan.address.prefix + "." + toString hostAddress;

        sshConfig = {
          Port         = 22;
          IdentityFile = "/home/ashley/.ssh/id_ed25519";
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

      # uci.sopsSecrets = "/home/ashley/shuurinet-nix/secrets/sops/openwrt.yaml";

      uci.retain = [ /* "dhcp" */ "dropbear" "firewall" "luci" "rpcd" "ucitrack" "uhttpd" ];

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
          };

          interface = helper.mkInterfaces {
            inherit hostAddress;
          };
        };

        firewall = helper.mkFirewall {
          extraRules = [
            { name = "avr_block_forward";                src = "iot"; src_ip = "${interfaces.iot.address.prefix}.118"; dest = "*"; target = "REJECT"; }
            { name = "living_room_switch_block_forward"; src = "lan"; src_ip = "${interfaces.lan.address.prefix}.5"; dest = "*"; target = "REJECT"; }
            { name = "kitchen_led_mqtt";                 src = "iot"; src_ip = "${interfaces.iot.address.prefix}.194"; dest = "lan"; dest_ip = "${interfaces.lan.address.prefix}.240"; dest_port = "1883"; target = "ACCEPT"; }
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