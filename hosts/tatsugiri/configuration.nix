# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  hostCfgVars         = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  hostAddress = "2";
  hostPrimaryIp = "${config.homelab.networks.subnets.bln-lan.ipv4}.${hostAddress}";

  deploymentMode = false;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ]; 

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host
  
  host.vars = {
    network = {
      hostName = "tatsugiri";
      staticIpConfig.enable = true;
      bridges = [
        # Management
        {
          name = "br2";
          memberInterfaces = [ "eno1" ];  
          subnet = config.homelab.networks.subnets.bln-mngmt;
          identifier = hostAddress;
          isPrimary = deploymentMode; 
        }

        # LAN
        {
          name = "br0";
          subnet = if deploymentMode then null else config.homelab.networks.subnets.bln-lan;
          identifier = if deploymentMode then null else hostAddress;
          isPrimary = !deploymentMode;
          tapDevices = [ "opnwrt-tap" "haos-tap" ];
        }

        # Apps
        {
          name = "br1";
          tapDevices = [ "opnwrt-apps-tap" ];
        }
      ];
    };

    storage = {
      paths = {
        bulkStorage = "/home/ashley";
      };
    };
  };
  
  deployment.bootstrap.gitClone.host = hostCfgVars.network.hostName;

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  systemd.services."fix-slow-builtin-ethernet" = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "systemd-networkd.service"
      "network.target"
    ];
    wants = [
      "network-online.target"
      "systemd-networkd.service"
      "network.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.iproute2}/bin/ip link set eno1 mtu 1492
        ${pkgs.ethtool}/bin/ethtool -C eno1 rx-usecs 768
      '';
    };
  };

  boot.kernelParams = [
    "pcie_aspm=force"
    "pcie_aspm.policy=powersave"
  ];

  environment.systemPackages = with pkgs; [
    python3
    ethtool
  ];

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  users.users.ashley.password = "temporary123";

  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024; # 16GB
  }];

  # -------------------------------- HARDWARE CONFIGURATION --------------------------------

  # Intel-specific & Power Saving
  intel.graphics.enable = true;
  powersave.enable = true; 

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.age";
    netbird-management-url.file = "${secretsAbsolutePath}/netbird-management-url.age";
    caddy-cloudflare.file = "${secretsAbsolutePath}/caddy-cloudflare.env.age";

    cloudflare-api-token.file = "${secretsAbsolutePath}/cloudflare-api-token.age";
    tatsugiri-wg-private-key.file = "${secretsAbsolutePath}/tatsugiri-wg-private-key.age";

    obsd-couchdb-config = {  
      file = "${secretsAbsolutePath}/obsd-couchdb-config.ini.age";
      owner = "couchdb";
      group = "couchdb";
    };
  };

  common.secrets.sopsKeyPath = config.age.secrets.sops-key.path;

  # -------------------------------- DISK CONFIGURATION --------------------------------

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/ata-SanDisk_SDSSDH3_250G_214676446013"; } # boot drive
    ];
  };

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  # -------------------------------- Virtualisation & VMs --------------------------------

  virtualisation = {
    intel.enable = true;
    
    qemu.manager = {
      images = {
        "openwrt" = {
          enable = true;
          # openwrt imagebuilder input is pinned to a specific revision to prevent updates upon flake update/rebuild -
          # to update the image, see flake.nix openwrt-imagebuilder input
          source = "file:///var/lib/vm/images/openwrt-full.qcow2";
          sourceSha256 = "127r2mzdhf6ykradxjsj0y2by5xilspkycck82bzky85sxx4asrv";
          sourceFormat = "qcow2";
          # compressedFormat = "gz";
        };
        
        "haos" = {
          enable = true;
          source = "https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz";
          sourceFormat = "qcow2";
          sourceSha256 = "0jbjajfnv3m37khk9446hh71g338xpnbnzxjij8v86plymxi063d";
          compressedFormat = "xz";
        };
      };

      # To 'factory reset VM, delete overlay in "/var/lib/vm/images" and restart service
      # VM service names are the names of the service attribute sets below, e.g. "openwrt" or "home-assistant"
      services = {
        "openwrt" = {
          enable     = true;
          baseImage  = "openwrt";
          uefi       = true;
          memory     = 1024;
          smp        = 4;
          taps       = [ 
            { name = "opnwrt-tap";      macAddress = "fe:b5:aa:1f:29:24"; }
            { name = "opnwrt-apps-tap"; macAddress = "fe:b5:aa:1f:29:21"; }
          ];
          bridges    = [ "br0" "br1" ];
          pciHosts   = [ 
            { address = "01:00.0"; vendorDeviceId = "8086:150e"; } 
            { address = "01:00.1"; }
            { address = "01:00.2"; }
            { address = "01:00.3"; }
          ];
          vncPort   = 1;
        };

        "home-assistant" = {
          enable     = true;
          baseImage  = "haos";
          uefi       = true;
          memory     = 3072;
          smp        = 2;
          taps       = [ 
            { name = "haos-tap"; macAddress = "ce:b0:37:6d:1a:de"; }
          ];
          bridges    = [ "br0" ];
          rootScsi   = true;
          vncPort    = 2;
        };
      };
    };
  };

  # OpenWrt Config Auto-Deploy
  # openwrt.config-auto-deploy = {
  #   enable = true;
  #   sopsAgeKeyFile = config.age.secrets.sops-key.path;

  #   configs = {
  #     berlin-router-config = {
  #       drv = inputs.self.packages.${pkgs.system}.berlin-router-config;
  #       imageDrv = inputs.self.packages.${pkgs.system}.berlin-router-img;
  #       serviceName = "openwrt";
  #       host = "192.168.11.1";
  #     };  
  #   };
  # };

  ### Containers
  netbird.router = {
    enable = true;
    
    managementUrlPath = config.age.secrets.netbird-management-url.path;
    
    # peers = {
    #   master = {
    #     enable = lib.mkForce true;
    #     setupKey = config.age.secrets.missingno-netbird-master-setup-key.path;
    #     hostInterface = "br0";
    #     hostSubnet = config.homelab.networks.subnets.bln-lan.ipv4;
    #   };

    #   apps = {
    #     enable = lib.mkForce true;
    #     setupKey = config.age.secrets.missingno-netbird-apps-setup-key.path;
    #     hostSubnet = config.homelab.networks.subnets.bln-apps.ipv4; 
    #   };
    # };
  };

  # -------------------------------- Services --------------------------------

  ### Obsidian Livesync
  services.couchdb = {
    enable = true;
    configFile = config.age.secrets.obsd-couchdb-config.path;
    bindAddress = hostPrimaryIp;
  };

  caddy = {
    enable = true;
    environmentFile = config.age.secrets.caddy-cloudflare.path;
    defaultSite = "bln";

    virtualHosts = {
      "home-manager" = {
        name = "tatsugiri";
        site = null;
        destinationPort = 8082;
      };

      "obsidian-livesync" = {
        name = "obsidian-livesync";
        destinationPort = 5984;
      };
    };
  };

  # -------------------------------- Remote Access --------------------------------

  remoteAccess = {
    ddns = {
      enable = true;
      tokenFile = config.age.secrets.cloudflare-api-token.path;
      zone = "shuuri.net";
      domains = [ "rmt.bln.shuuri.net" ];
    };

    wireguard = {
      enable = true;

      host = {
        bridge = "br0";
        subnet = "192.168.11";
      };

      privateKeyFile = config.age.secrets.tatsugiri-wg-private-key.path;
      ips = [ "10.100.88.1/32" ];
      port = 58134;

      peers = [
        {
          name = "rotom-laptop";
          publicKey = "2tdesOokkHYhXKeizN69iczaK7YIP+cqzMUneX/EqiA=";
          allowedIPs = [ "10.100.88.0/24" ];
        }
        {
          name = "tats-kodi-box";
          publicKey = "WdBIvTH0MpRxYyI6exP7xhP6zO+qo/WNnGwGuIhqm1A=";  # Replace with actual public key
          allowedIPs = [ "10.100.88.1/32" ];  # Use a unique IP for this peer
        }
      ];
    };
  };
}