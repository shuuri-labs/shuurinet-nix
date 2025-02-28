# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, ... }:

let
  hostCfgVars = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  linuxUefiVmTemplate = import ../../lib/vm-templates/nixvirt-linux-uefi-host-network.nix { inherit pkgs nixvirt; };

  inherit (inputs) nixvirt;
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
      config = {
        hostName = "tatsugiri";
        interfaces = []; 
        bridge = "br0";
        unmanagedInterfaces = config.host.vars.network.config.interfaces ++ [ config.host.vars.network.config.bridge "br1" ];
        subnet = config.homelab.networks.subnets.bln; # see options-homelab/networks.nix
        hostIdentifier = "121";
      };

      staticIpConfig.enable = true;
    };
  };

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
    # mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad.conf.age";
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
  };

  # -------------------------------- DISK CONFIGURATION --------------------------------

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/ata-SanDisk_SDSSDH3_250G_214676446013"; } # boot drive
    ];
  };

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  # -------------------------------- HARDWARE FEATURES --------------------------------

  # Intel-specific & Power Saving
  intelGraphics.enable = true;
  powersave.enable = true; 

  # -------------------------------- Virtualisation & VMs --------------------------------

  users.users.ashley.extraGroups = [ "libvirtd" ];

  # 'vfio-pci ids='disable these devices from the host and pass them through on boot
  # (get device ids from lspci -nn, at end of each line is [vendorId:deviceId])
  boot.extraModprobeConfig = lib.mkAfter ''
    options vfio-pci ids=8086:1521,8086:1521,8086:1521,8086:1521
  '';

  virtualization = {
    intel.enable = true;
    nixvirt = {
      enable = true;
      pools.main = {
        uuid = "f2df67ce-da92-4462-8703-775f4af16dbb";
        images.path = "/var/lib/vms/images";
      };
    };

    openwrt.vm = {
      uuid = "62aa3719-7cdc-4ed6-a1c6-5fbf5d735179";

      hostManagementInterface = "br1";

      nicHostDevs = [
        {
          type = "pci";
          source = {
            address = {
              domain = 0;
              bus = 1;
              slot = 0;
              function = 0;
            };
          };
        }
        {
          type = "pci";
          source = {
            address = {
              domain = 0;
              bus = 1;
              slot = 0;
              function = 1;
            };
          };
        }
        {
          type = "pci";
          source = {
            address = {
              domain = 0;
              bus = 1;
              slot = 0;
              function = 2;
            };
          };
        }
        {
          type = "pci";
          source = {
            address = {
              domain = 0;
              bus = 1;
              slot = 0;
              function = 3;
            };
          };
        }
      ];
    };
  };
}
    
    