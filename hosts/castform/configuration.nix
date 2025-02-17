# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, ... }:

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

  virtualisation.libvirt = {
    enable = true;
    
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
          # volumes = [
            # {
            #   definition = nixvirt.lib.volume.writeXML {
            #     name = "openwrt.qcow2";
            #     capacity = { count = 1; unit = "GiB"; };
            #     target = {
            #       format = { type = "qcow2"; };
            #     };
            #     backingStore = {
            #       path = "/var/lib/libvirt/images/openwrt-24.10.0-x86-64-generic-ext4-combined-efi.raw";
            #       format = { type = "raw"; };
            #     };
            #   };
            # }
            # {
            #   definition = nixvirt.lib.volume.writeXML {
            #     name = "home-assistant.qcow2";  # New overlay disk name
            #     capacity = { count = 32; unit = "GiB"; };
            #     target = {
            #       format = { type = "qcow2"; };
            #     };
            #     backingStore = {
            #       path = "/var/lib/libvirt/images/haos_ova-14.2.qcow2";
            #       format = { type = "qcow2"; };
            #     };
            #   };
            # }
          # ];
        }
      ];

      # networks = [{
      #   definition = nixvirt.lib.network.writeXML (
      #     nixvirt.lib.network.templates.bridge {
      #       name = "default";
      #       uuid = "27ca47f3-2490-4d1e-9d7e-2b9c1d3d7374";  # generate a new UUID
      #       bridge_name = "virbr0";
      #       subnet_byte = 122;  # This will create a 192.168.122.0/24 network
      #     }
      #   );
      #   active = true;
      # }];
      
      domains = [{
        definition = nixvirt.lib.domain.writeXML (
          let
            baseTemplate = nixvirt.lib.domain.templates.linux {
              name = "openwrt";
              uuid = "cc7439ed-36af-4696-a6f2-1f0c4474d87e";
              memory = { count = 256; unit = "MiB"; };
              storage_vol = null;
            };
          in
            baseTemplate // {
              vcpu = {
                count = 2;
              };
              
              os = baseTemplate.os // {
                loader = {
                  readonly = true;
                  type = "pflash";
                  path = "${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd";
                };
                nvram = {
                  template = "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.fd";
                  path = "/var/lib/libvirt/qemu/nvram/openwrt_VARS.fd";
                };
                boot = [{ dev = "hd"; }];
              };

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
                    volume = "openwrt-24.10.0-x86-64-generic-ext4-combined-efi.raw";
                  };
                  target = {
                    dev = "vda";
                    bus = "virtio";
                  };
                  boot = { order = 1; };
                }];

                interface = {
                  type = "bridge";
                  source = { bridge = "br0"; };
                  model = { type = "virtio"; };
                };

                serial = [{
                  type = "pty";
                }];

                console = [{
                  type = "pty";
                  target = {
                    type = "serial";
                    port = 0;
                  };
                }];

                graphics = [
                  {
                    type = "vnc";
                    listen = { type = "address"; address = "127.0.0.1"; };
                    port = 5900;
                    attrs = {
                      passwd = "changeme";
                    };
                  }
                  {
                    type = "spice";
                    listen = { type = "address"; address = "127.0.0.1"; };
                    autoport = true;
                    image = { compression = false; };
                    gl = { enable = false; };
                  }
                ];

                video = {
                  model = {
                    type = "virtio";
                    vram = 32768;
                    heads = 1;
                    primary = true;
                  };
                };

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
            baseTemplate = nixvirt.lib.domain.templates.linux {
              name = "home-assistant";
              uuid = "cc7439ed-36af-4696-a6f2-1f0c4454d87e";
              memory = { count = 512; unit = "MiB"; }; 
              storage_vol = null;
            };
          in
            baseTemplate // {
              vcpu = {
                count = 2;
              };

              os = baseTemplate.os // {
                loader = {
                  readonly = true;
                  type = "pflash";
                  path = "${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd";
                };
                nvram = {
                  template = "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.fd";
                  path = "/var/lib/libvirt/qemu/nvram/home-assistant_VARS.fd";
                };
                boot = [{ dev = "hd"; }];
              };

              devices = baseTemplate.devices // {
                serial = [{
                  type = "pty";
                }];
                console = [{
                  type = "pty";
                  target = {
                    type = "serial";
                    port = 0;
                  };
                }];

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
                    volume = "haos_ova-14.2-2.qcow2";
                  };
                  target = {
                    dev = "sda";
                    bus = "scsi";
                  };
                  boot = { order = 1; };
                }];

                interface = {
                  type = "bridge";
                  source = { bridge = "br0"; };
                  model = { type = "virtio"; };
                };

                graphics = [
                  {
                    type = "vnc";
                    listen = { type = "address"; address = "127.0.0.1"; };
                    port = 5901;
                    attrs = {
                      passwd = "changeme";
                    };
                  }
                  {
                    type = "spice";
                    listen = { type = "address"; address = "127.0.0.1"; };
                    autoport = true;
                    image = { compression = false; };
                    gl = { enable = false; };
                  }
                ];

                video = {
                  model = {
                    type = "virtio";
                    vram = 32768;
                    heads = 1;
                    primary = true;
                  };
                };
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