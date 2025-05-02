# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  hostCfgVars = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 
  
  # Create a derivation that contains just the AML file
  # facp_package = pkgs.runCommand "facp-override" {} ''
  #   mkdir -p $out/kernel/firmware/acpi
  #   cp ${./FADT_override.aml} $out/kernel/firmware/acpi/FACP.aml
  # '';
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
      hostName = "missingno";
      staticIpConfig.enable = true;
      bridges = [
        {
          name = "br0";
          memberInterfaces = [ "enp2s0" "enp1s0f0" ];  
          subnet = config.homelab.networks.subnets.bln;
          identifier = "151";
          isPrimary = true;
          tapDevices = [ "openwrt-tap" "haos-tap" ];
        }
      ];
    };

    storage = {
      paths = {
        bulkStorage = "/home/ashley";
      };
    };
  };

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  # Custom kernel with igc patch for PCIE L1.2 state exit latency fix

  # boot.kernelPatches = [{
  #   name = "acpi-table-upgrade";
  #   patch = null;
  #   extraConfig = ''
  #     ACPI_TABLE_UPGRADE y
  #   '';
  # }];

  # # Create a custom initrd that includes your ACPI tables
  # boot.initrd = {
  #   extraUtilsCommands = ''
  #     cp -rv ${facp_package}/* $out/
  #   '';
  # };

  boot.kernelParams = [
    "pcie_aspm=force"
    "pcie_aspm.policy=powersave"
    # "vfio-pci.ids=8086:150e"
  ];

  environment.systemPackages = with pkgs; [
    python3
    acpica-tools
  ];

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  # users.users.ashley.password = "temporary123";

  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024; # 16GB
  }];

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
  #   castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
  #   ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
  #   media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.txt.age";
  };

  # -------------------------------- DISK CONFIGURATION --------------------------------

  # zfs = {
  #   pools = {
  #     rust = {
  #       name = "castform-rust";
  #       autotrim = false;
  #     };
  #   };
  #   network.hostId = "c8f36183"; 
  # };

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

  virtualization = {
    intel.enable = true;
  };

  virtualisation.qemu.manager = {
    images = {
      "openwrt" = {
        enable = true;
        # source = "file:///var/lib/libvirt/images/openwrt-24.10.0-x86-64-generic-ext4-combined-efi-newest.raw";
        source = inputs.self.packages.${pkgs.system}.berlin-router-img;
        sourceFormat = "raw";
        compressedFormat = "gz";
        # sourceSha256 = "198gr1j3lcjwvf1vqk8ldk1ddwd9n2sv44yza63ziz1dw2643a0g";
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
        memory    = 1024;
        smp       = 8;
        taps      = [ "openwrt-tap" ];
        bridges   = [ "br0" ];
        pciHosts  = [ 
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
        taps       = [ "haos-tap" ];
        bridges    = [ "br0" ];
        rootScsi   = true;
        vncPort    = 2;
      };
    };
  };
}
