# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  hostCfgVars         = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  hostAddress = "42";
  hostSubnet = config.homelab.networks.subnets.tats;
  hostPrimaryIp = "${hostSubnet.ipv4}.${hostAddress}";

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
      hostName = "misdreavus";
      staticIpConfig.enable = true;
      bridges = [
        {
          name = "br0";
          memberInterfaces = [ "enp1s0" ];  
          subnet = hostSubnet;
          identifier = hostAddress;
          isPrimary = true;
          # tapDevices = [ "haos-tap" ];
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

  boot.kernelParams = [
    "pcie_aspm=force"
    "pcie_aspm.policy=powersave"
  ];

  boot.blacklistedKernelModules = [ "r8169" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ r8168 ];

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
    caddy-cloudflare.file = "${secretsAbsolutePath}/caddy-cloudflare.env.age";
    cloudflare-api-token.file = "${secretsAbsolutePath}/cloudflare-api-token.age";
    misdreavus-wg-prv-key.file = "${secretsAbsolutePath}/misdreavus-wg-prv-key.age";
  };

  # -------------------------------- DISK CONFIGURATION --------------------------------

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/ata-INTENSO_SSD_1642410001005008"; } # boot drive
    ];
  };

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  # -------------------------------- Virtualisation & VMs --------------------------------

  virtualisation = {
    intel.enable = true;
    
    qemu.manager = {
      images = {
        "haos" = {
          enable = true;
          source = "https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz";
          sourceFormat = "qcow2";
          sourceSha256 = "0jbjajfnv3m37khk9446hh71g338xpnbnzxjij8v86plymxi063d";
          compressedFormat = "xz";
        };
      };

      # To 'factory reset' VM, delete overlay in "/var/lib/vm/images" and restart service
      # VM service names are the names of the service attribute sets below, e.g. "openwrt" or "home-assistant"
      services = {
        "home-assistant" = {
          enable     = true;
          baseImage  = "haos";
          uefi       = true;
          memory     = 3072;
          smp        = 2;
          taps       = [ 
            { name = "haos-tap"; macAddress = "8e:56:d7:e3:4a:44"; }
          ];
          bridges    = [ "br0" ];
          # usbHosts   = [ { vendorId = "4292"; productId = "60000"; } ];
          rootScsi   = true;
          vncPort    = 2;
          extraArgs = [
            "usb"
            "device qemu-xhci,id=xhci"
            "device usb-host,bus=xhci.0,vendorid=0x10c4,productid=0xea60"
          ];
        };
      };
    };
  };

  # -------------------------------- Services --------------------------------

  remoteAccess = {
    ddns = {
      enable = true;
      tokenFile = config.age.secrets.cloudflare-api-token.path;
      zone = "shuuri.net";
      domains = [ "rmt.tats.shuuri.net" ];
    };

    wireguard = {
      enable = true;

      host.bridge = "br0";
    
      privateKeyFile = config.age.secrets.misdreavus-wg-prv-key.path;
      ips = [ "10.100.44.1/32" ];
      port = 58135;

      peers = [
        {
          name = "rotom-laptop";
          publicKey = "2tdesOokkHYhXKeizN69iczaK7YIP+cqzMUneX/EqiA=";
          ip = "10.100.44.2/32";
        }
      ];
    };
  };
}