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
    # ./disk-config.nix
    ./samba-config.nix
  ];

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host

  host.vars = {
    network = {
      config = {
        hostName = "castform";
        interfaces = [ "enp0s31f6" ]; 
        bridge = "br0";
        unmanagedInterfaces = config.host.vars.network.config.interfaces ++ [ config.host.vars.network.config.bridge ];
        subnet = config.homelab.networks.subnets.bln; # see options-homelab/networks.nix
        hostIdentifier = "121";
      };

      staticIpConfig.enable = true;
    };

    storage = {
      paths = {
        bulkStorage = "/castform-rust";
      };
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
  intelGraphics.enable = true;
  boot.kernelParams = [ "intremap=no_x2apic_optout" ]; # ignore fujitsu bios error 
  powersave.enable = true; 
  
  # -------------------------------- FILE SERVER --------------------------------

  # Samba - configured in ./samba-config.nix
  sambaProvisioner.enable = true;

  # -------------------------------- HOSTED SERVICES --------------------------------

  # Media Server
  # mediaServer.enable = true;
  # mediaServer.vpnConfinement.wireguardConfigFile = config.age.secrets.mullvad-wireguard-config.path; 
  # mediaServer.vpnConfinement.lanSubnet = hostCfgVars.network.config.subnet.ipv4;
  # mediaServer.vpnConfinement.lanSubnet6 = hostCfgVars.network.config.subnet.ipv6;

  # mediaServer.storage.path = hostCfgVars.storage.directories.media;
  # mediaServer.storage.group = hostCfgVars.storage.accessGroups.media.name;
  # mediaServer.storage.hostMainStorageUser = "ashley";

  # mediaServer.services.downloadDir = hostCfgVars.storage.directories.downloads; 
  # mediaServer.services.downloadDirAccessGroup = hostCfgVars.storage.accessGroups.downloads.name;
  # mediaServer.services.mediaDirAccessGroup = hostCfgVars.storage.accessGroups.media.name;

  # -------------------------------- Virtualisation & VMs --------------------------------

  users.users.ashley.extraGroups = [ "libvirtd" ];

  # 'vfio-pci ids='disable these devices from the host and pass them through on boot
  # (get device ids from lspci -nn, at end of each line is [vendorId:deviceId])
  boot.extraModprobeConfig = lib.mkAfter ''
    options vfio-pci ids=15b3:1015,15b3:1015
  '';

  boot.blacklistedKernelModules = [ "mlx5_core" ]; # block mellanox drivers on host to prevent passthrough interference
  
  networking.firewall = {
    allowedTCPPorts = [ 67 68 5900 5901 ];
    allowedUDPPorts = [ 67 68 5900 5901 ];
    extraCommands = ''
      iptables -A FORWARD -i br0 -j ACCEPT
      iptables -A FORWARD -o br0 -j ACCEPT
    '';
  };

  virtualization = {
    intel.enable = true;
    nixvirt = {
      enable = true;
      pools.main = {
        uuid = "4acdd24f-9649-4a24-8739-277c822c6639";
        images.path = "/var/lib/libvirt/images";
      };
    };
  };

  virtualisation.libvirt = {
    enable = true;
    
    connections."qemu:///system" = {      
      domains = [{
        definition = nixvirt.lib.domain.writeXML (
          let
            baseTemplate = linuxUefiVmTemplate.mkCustomVmTemplate {
              name = "openwrt";
              uuid = "cc7439ed-36af-4696-a6f2-1f0c4474d87e";
              memoryMibCount = 512;
              hostInterface = "br0";
            };
          in
            baseTemplate // {
              devices = baseTemplate.devices // {
                disk = [{
                  type = "volume";
                  device = "disk";
                  driver = {
                    name = "qemu";
                    type = "raw";
                    cache = "none";
                    discard = "unmap";
                  };
                  source = {
                    pool = "default";
                    volume = "openwrt-build-1.raw";
                  };
                  target = {
                    dev = "vda";
                    bus = "virtio";
                  };
                }];

                hostdev = [
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
                ];
              };
            }
        );
        active = true;
      }
      {
        definition = nixvirt.lib.domain.writeXML (
          let
            baseTemplate = linuxUefiVmTemplate.mkCustomVmTemplate {
              name = "home-assistant";
              uuid = "c87b7237-8169-42c1-b5cc-6d02624d6341"; # uuidgen 
              memoryMibCount = 3072;
              hostInterface = "br0";
            };
          in
            baseTemplate // {
              devices = baseTemplate.devices // {
                controller = [{
                  type = "scsi";
                  model = "virtio-scsi";
                }];

                disk = [{
                  type = "volume";
                  device = "disk";
                  driver = {
                    name = "qemu";
                    type = "qcow2";
                    cache = "none";
                    discard = "unmap";
                  };
                  source = {
                    pool = "default";
                    volume = "haos_ova-14.2-newest-2.qcow2";
                  };
                  target = {
                    dev = "sda";
                    bus = "scsi";
                  };
                }];
              };
            }
        );
        active = true;
      }];
    };
  };
}

# sudo virsh list --all
# ls -l /nix/store/*NixVirt*
# sudo virsh console openwrt
# sudo virsh start openwrt
# sudo virsh destroy openwrt

# List all pools
# sudo virsh pool-list

# Refresh the specific pool (in your case, "default")
# sudo virsh pool-refresh default

# You can also try stopping and starting the pool
# sudo virsh pool-destroy default
# sudo virsh pool-start default

# To verify the volume exists
# sudo virsh vol-list default

#sudo virsh dumpxml home-assistant


# ssh -L 5900:127.0.0.1:5900 castform