# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

let
  hostCfgVars = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

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

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad.conf.age";
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

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  # -------------------------------- HARDWARE FEATURES --------------------------------

  # Intel-specific & Power Saving
  intelGraphics.enable = true;
  boot.kernelParams = [ "intremap=no_x2apic_optout" ]; # ignore fujitsu bios error 
  powersave.enable = true; 
  virtualization.intel.enable = true;
  hddSpindown.disks = [ "ata-WDC_WD10EZEX-07WN4A0_WD-WCC6Y3ESH5SP" ];

  # -------------------------------- FILE SERVER --------------------------------

  # Samba - configured in ./samba-config.nix
  sambaProvisioner.enable = true;

  # -------------------------------- HOSTED SERVICES --------------------------------

  # Media Server
  mediaServer.enable = true;
  mediaServer.vpnConfinement.wireguardConfigFile = config.age.secrets.mullvad-wireguard-config.path; 
  mediaServer.vpnConfinement.lanSubnet = hostCfgVars.network.config.subnet.ipv4;
  mediaServer.vpnConfinement.lanSubnet6 = hostCfgVars.network.config.subnet.ipv6;

  mediaServer.mediaDir = hostCfgVars.storage.directories.media;
  mediaServer.mediaGroup = hostCfgVars.storage.accessGroups.media.name;
  mediaServer.hostMainStorageUser = "ashley";

  mediaServer.services.downloadDir = hostCfgVars.storage.directories.downloads; 
  mediaServer.services.downloadDirAccessGroup = hostCfgVars.storage.accessGroups.downloads.name;
  mediaServer.services.mediaDirAccessGroup = hostCfgVars.storage.accessGroups.media.name;

  # -------------------------------- VMs --------------------------------

  users.users.ashley.extraGroups = [ "libvirtd" ];

  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;

    connections."qemu:///system" = {
      pools = [
        {
          definition = nixvirt.lib.pool.writeXML {
            name = "default";
            uuid = "4acdd24f-9649-4a24-8739-277c822c6639";
            type = "dir";
            target = {
              path = "/var/lib/libvirt/images";
            };
          };
          active = true;
          volumes = [
            {
              definition = nixvirt.lib.volume.writeXML {
                name = "openwrt.qcow2";
                uuid = "05a1b7c8-d3e4-4f5a-9b2c-6d7e8f9a0b1c";
                capacity = { count = 1; unit = "GiB"; };
                target = {
                  path = "/var/lib/libvirt/images/openwrt.qcow2";
                  format = { 
                    type = "qcow2"; 
                  };
                };
              };
            }
          ];
        }
      ];

      networks = [{
        definition = nixvirt.lib.network.writeXML (
          nixvirt.lib.network.templates.bridge {
            name = "default";
            uuid = "27ca47f3-2490-4d1e-9d7e-2b9c1d3d7374";  # generate a new UUID
            bridge_name = "virbr0";
            subnet_byte = 122;  # This will create a 192.168.122.0/24 network
          }
        );
        active = true;
      }];
      
      domains = [{
        definition = nixvirt.lib.domain.writeXML (
          let
            baseTemplate = nixvirt.lib.domain.templates.linux {
              name = "openwrt";
              uuid = "cc7439ed-36af-4696-a6f2-1f0c4474d87e";
              memory = { count = 256; unit = "MiB"; };
              storage_vol = { pool = "default"; volume = "openwrt.qcow2"; };
            };
          in
            baseTemplate // {
              devices = baseTemplate.devices // {
                # Add to existing device types
                # disk = baseTemplate.devices.disk ++ [
                #   {
                    
                #   }
                # ];
                
                # Add new device types
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
      }];
    };
  };
}

# sudo virsh list --all
# ls -l /nix/store/*NixVirt*
# sudo virsh console openwrt
# sudo virsh start openwrt
# sudo virsh destroy openwrt
