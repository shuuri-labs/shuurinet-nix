# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  hostCfgVars = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

in
{
  imports = [
    ./hardware-configuration.nix
    # ./disk-config.nix
    ./samba-config.nix
  ];

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host

  host.vars = {
    network = {
      hostName = "castform";
      staticIpConfig.enable = true;
      
      bridges = [
        {
          name = "br0";
          memberInterfaces = [ "enp0s31f6" ];
          subnet = config.homelab.networks.subnets.bln-lan;
          identifier = "121";
          isPrimary = true;
        }
      ];
    };

    storage = {
      paths = {
        bulkStorage = "/castform-rust";
      };
    };
  };

  deployment.bootstrap.gitClone.host = hostCfgVars.network.hostName;

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;

  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024; # 16GB
  }];

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.txt.age";
  };

  common.secrets.sopsKeyPath = "${secretsAbsolutePath}/keys/sops-key.agekey.age";

  # -------------------------------- DISK CONFIGURATION --------------------------------

  zfs = {
    pools = {
      rust = {
        name = "castform-rust";
        autotrim = false;
      };
    };
    network.hostId = "c8f36183"; 
  };

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/ata-SanDisk_SDSSDH3_250G_214676446013"; } # boot drive
      { device = "/dev/disk/by-id/ata-WDC_WD10EZEX-07WN4A0_WD-WCC6Y3ESH5SP"; } # drive 1
    ];
  };

  hddSpindown.disks = [ "ata-WDC_WD10EZEX-07WN4A0_WD-WCC6Y3ESH5SP" ];

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  # -------------------------------- HARDWARE FEATURES --------------------------------

  # Intel-specific & Power Saving
  intel.graphics.enable = true;
  powersave.enable = true; 
  boot.kernelParams = [ "intremap=no_x2apic_optout" ]; # ignore fujitsu bios error 

  # -------------------------------- Virtualisation & VMs --------------------------------

  virtualisation = {
    intel.enable = true;

    qemu.manager = {
      images = {
        "openwrt" = {
          enable = true;
          source = inputs.self.packages.${pkgs.system}.berlin-router-img;
          sourceFormat = "raw";
          compressedFormat = "gz";
        };
        
        "haos" = {
          enable = true;
          source = "https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz";
          sourceFormat = "qcow2";
          sourceSha256 = "0jbjajfnv3m37khk9446hh71g338xpnbnzxjij8v86plymxi063d";
          compressedFormat = "xz";
        };
      };

      services = {
        "openwrt" = {
          enable    = true;
          baseImage = "openwrt";
          uefi      = true;
          memory    = 256;
          smp       = 4;
          bridges   = [ "br0" ];
          pciHosts  = [ { address = "01:00.0"; vendorDeviceId = "15b3:1015"; } { address = "01:00.1"; } ];
          vncPort   = 1;
        };

        "home-assistant" = {
          enable     = true;
          baseImage  = "haos";
          uefi       = true;
          memory     = 3072;
          smp        = 2;
          bridges    = [ "br0" ];
          rootScsi   = true;
          vncPort    = 2;
        };
      };
    };
  };
}

# ssh -L 5901:127.0.0.1:5901 castform