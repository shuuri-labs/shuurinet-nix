# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  hostCfgVars = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  linuxUefiVmTemplate = import ../../lib/vm-templates/nixvirt-linux-uefi-host-network.nix { inherit pkgs nixvirt; };

  inherit (inputs) nixvirt;

  uuidgen = import ../../lib/utils/uuidgen.nix { inherit pkgs; };
  libvirtPoolUUID = uuidgen "libvirt-pool-uuid";
  bridgeUUID = uuidgen "bridge-uuid";

  deploymentMode = true; 
  homeAssistantImageName = "haos_ova-15.2.qcow2";
  openwrtImageName = "openwrt-24.10.0-x86-64-generic-ext4-combined-efi.raw";
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
        staticIpConfig.enable = !deploymentMode;
        
        bridges = [
          {
            name = "br0";
            memberInterfaces = []; # TODO: find correct interface name
            subnet = config.homelab.networks.subnets.bln;
            identifier = "2";
            isPrimary = true;
          }
          {
            name = "mgmt0";
            memberInterfaces = []; # TODO: find correct interface name
            subnet = {
                ipv4 = "10.10.55";
            };
            identifier = "21";
            isPrimary = true;
          }
        ];
      };
    };

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;

  swapDevices = [{
    device = "/swapfile";
    size = 8 * 1024; # 16GB
  }];

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.txt.age";
  };

  # -------------------------------- DISK CONFIGURATION --------------------------------

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/ata-SanDisk_SDSSDH3_250G_214676446013"; } # boot drive TODO: find correct device id
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
    options vfio-pci ids=15b3:1015,15b3:1015
  ''; # TODO: populate with correct device ids

  boot.blacklistedKernelModules = []; # block intel i350 drivers on host to prevent passthrough interference # TODO: find i350 driver name
  


  # -------------------------------- VIRTUALISATION --------------------------------

  # Unblock VNC ports, allow forwarding on bridges connected to VMs
  # TODO: move forwarding to network module, enable with flag
  networking.firewall = {
    allowedTCPPorts = [ 5900 5901 ];
    allowedUDPPorts = [ 5900 5901 ];
    extraCommands = ''
      iptables -A FORWARD -i br0 -j ACCEPT 
      iptables -A FORWARD -o br0 -j ACCEPT
    '';
  };

  home-assistant.deploy = {
    enable = deploymentMode;
    imageName = homeAssistantImageName;
  };

  openwrt.deploy = {
    enable = deploymentMode;
    imageName = openwrtImageName;
  };

  virtualization = {
    intel.enable = true;
    nixvirt = {
      enable = true;
      pools.main = {
        uuid = uuidgen "libvirt-pool";;
        images.path = "/var/lib/vm/images";
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
              uuid = uuidgen "openwrt";
              memoryMibCount = 1024;
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
                    volume = openwrtImageName;
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
              uuid = uuidgen "home-assistant";
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
                    volume = homeAssistantImageName;
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