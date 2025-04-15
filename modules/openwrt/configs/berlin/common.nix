{
  firewall = {
    zone = [
      { name = "lan"; input = "ACCEPT"; output = "ACCEPT"; forward = "ACCEPT"; network = [ "lan" ]; }
      { name = "guest"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "guest" ]; }
      { name = "iot"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "iot" ]; }
      { name = "apps"; input = "REJECT"; output = "ACCEPT"; forward = "REJECT"; network = [ "apps" ]; }
    ];
  };

  network = {
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
        ipaddr = "192.168.11.1";
        netmask = "255.255.255.0";
        ip6assign = "60";
        # dns = [ "192.168.11.1" ];
      };

      guest = {
        proto = "static";
        device = "br-lan.22";
        ipaddr = "10.10.23.1";
        netmask = "255.255.255.0";
        # dns._secret = "host.dns.ipList";
      };

      iot = {
        proto = "static";
        device = "br-lan.33";
        ipaddr = "10.10.34.1";
        netmask = "255.255.255.0";
        # dns._secret = "host.dns.ipList";
      };

      apps = {
        proto = "static";
        device = "br-lan.44";
        ipaddr = "10.10.45.1";
        netmask = "255.255.255.0";
        # dns._secret = "host.dns.ipList";
      };
    };
  };
}

# nix build .#berlin-router-config --show-trace
# sudo -E ./result/bin/deploy-berlin-router-config 