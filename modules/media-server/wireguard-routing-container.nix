{ config, lib, pkgs, ... }:

let
  cfg = config.mediaServer.network.wg-mullvad;

  # Mullvad configuration
  mullvadPrivateKey = "6EUR4rzV5nsQ+NMihNfDFb1Aod9J4O6oYxgypZSDfUE="; # pkgs.agenix.decryptFile ../secrets/mullvad-private-key.age; # TODO: fix agenix
  mullvadPublicKey  = "qZbwfoY4LHhDPzUROFbG+LqOjB0+Odwjg/Nv3kGolWc="; # pkgs.agenix.decryptFile ../secrets/mullvad-public-key.age; # TODO: fix agenix
  mullvadAddressIpv4 = "10.66.28.22";
  mullvadAddressIpv6 = "fc00:bbbb:bbbb:bb01::3:1c15";
  mullvadEndPoint    = "185.65.135.68:51820";
  mullvadDns         = [ "10.64.0.1" ];

  # Common container configuration
  makeWireguardContainerSettings = { subnet, subnet6, arrMissionAddressesAndPorts, stateVersion }: {
    system.stateVersion = stateVersion;

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    networking = {
      enableIPv6 = true;
      useHostResolvConf = lib.mkForce false;

      firewall = {
        enable = true;
        allowedTCPPorts = lib.mapAttrsToList (_: service: service.port) arrMissionAddressesAndPorts;

        extraCommands = ''
          # Port forwarding for arrMission services
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: service: ''
            # Forward ${name} (${toString service.port})
            iptables -t nat -A PREROUTING -p tcp --dport ${toString service.port} -j DNAT --to-destination ${subnet}.${service.address}:${toString service.port}
            iptables -A FORWARD -p tcp -d ${subnet}.${service.address} --dport ${toString service.port} -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
          '') arrMissionAddressesAndPorts)}

          # Enable NAT
          iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
          ip6tables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

          # Allow forwarding
          iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT
          iptables -A FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
          
          ip6tables -A FORWARD -i eth0 -o wg0 -j ACCEPT
          ip6tables -A FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        '';
      };
    };

    services.resolved.enable = true;

    services.dnsmasq = {
      enable = true;
      settings = {
        listen-address = [
          "${subnet}.${config.mediaServer.container.network.wireguardAddress}"
          "${subnet6}::${config.mediaServer.container.network.wireguardAddress}"
        ];
        server = mullvadDns;
        cache-size = 150;
        bind-interfaces = true;
        no-resolv = true;
      };
    };

    networking.wireguard.enable = true;
    networking.wg-quick.interfaces = {
      wg0 = {
        address = [
          "${mullvadAddressIpv4}/32"
          "${mullvadAddressIpv6}/128"
        ];
        dns = mullvadDns;
        privateKey = mullvadPrivateKey;
        peers = [
          {
            publicKey = mullvadPublicKey;
            allowedIPs = [ "0.0.0.0/0" "::/0" ];
            endpoint = mullvadEndPoint;
          }
        ];
        postUp = ''
          iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) \
            -m addrtype ! --dst-type LOCAL \
            ! -d ${subnet}.0/24 -j REJECT
          ip6tables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) \
            -m addrtype ! --dst-type LOCAL -j REJECT
        '';
        preDown = ''
          iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) \
            -m addrtype ! --dst-type LOCAL \
            ! -d ${subnet}.0/24 -j REJECT
          ip6tables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) \
            -m addrtype ! --dst-type LOCAL -j REJECT
        '';
      };
    };
  };

in {
  options.mediaServer.network.wg-mullvad.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable Mullvad VPN wireguard container";
  };

  imports = [ 
    ../host/system/enable-host-container-networking-nat.nix 
  ];

  config = lib.mkIf cfg.enable {
    hypervisor.ct.networkingNat = {
      enable = true; # TODO change or remove
      interfaceExternal = config.mediaServer.container.network.interfaceExternal;
    };

    networking.firewall.allowedTCPPorts = lib.mapAttrsToList (_: service: service.port) config.mediaServer.container.network.arrMissionAddressesAndPorts;
    
    containers.wireguard = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = config.mediaServer.container.network.hostAddress;
      localAddress = "${config.mediaServer.container.network.subnet}.${config.mediaServer.container.network.wireguardAddress}";
      hostAddress6 = config.mediaServer.container.network.hostAddress6;
      localAddress6 = "${config.mediaServer.container.network.subnet6}::${config.mediaServer.container.network.wireguardAddress}";

      config = { pkgs, ... }: let
        containerSettings = makeWireguardContainerSettings {
          inherit (config.mediaServer.container.network) 
            subnet 
            subnet6 
            arrMissionAddressesAndPorts;
          inherit (config.system) stateVersion;
        };
      in containerSettings;
    };
  };
}