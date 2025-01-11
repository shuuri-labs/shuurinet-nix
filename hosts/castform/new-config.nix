# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  vars = {
    network = {
      interfaces = [ "enp0s31f6" ]; 
      bridge = "br0";

      subnet = config.homelab.networks.subnets.bln;

      hostAddress = "${vars.network.subnet.ipv4}.121";
      hostAddress6 = "${vars.network.subnet.ipv6}::121";
    };

    zfs = {
      pools = [ "castform-rust" ];
      network.hostId = "c8f36183"; 
    };

    paths = {
      bulkStorage = "/castform-rust";
    };

    disksToSpindown = [ "ata-WDC_WD10EZEX-07WN4A0_WD-WCC6Y3ESH5SP" ];
  };

  modulesDir = "../../modules";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/zfs
    ../../modules/hdd-spindown
    ../../modules/intel-graphics
    ../../modules/power-saving
    ../../modules/intel-virtualization
    ../../modules/media-server-2
  ];

  # Bootloader
  boot.loader.grub.enable = true;
  # Allow GRUB to write to EFI variables
  boot.loader.efi.canTouchEfiVariables = true;
  # Specify the target for GRUB installation
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev"; # For UEFI systems

  # Networking
  networking = {
    hostName = "castform";

    # Bridge Definition
    bridges.${vars.network.bridge} = {
      interfaces = vars.network.interfaces;
    };

    # bridge interface config
    interfaces."${vars.network.bridge}" = {
      useDHCP = false;

      ipv4 = {
        addresses = [{
          address = vars.network.hostAddress;
          prefixLength = 24;
        }];
      };

      ipv6 = {
        addresses = [{
          address = vars.network.hostAddress6;  # Ensure proper IPv6 formatting
          prefixLength = 64;
        }];
      };
    };

    # Default Gateways
    defaultGateway = {
      address = "${vars.network.subnet.ipv4}.1";
      interface = vars.network.bridge;
    };

    defaultGateway6 = {
      address = "${vars.network.subnet.ipv6}::1";
      interface = vars.network.bridge;
    };

    # Nameservers
    nameservers = [ 
      "${vars.network.subnet.ipv4}.1" 
      "${vars.network.subnet.ipv6}::1"
    ];
  };

  # Enable networking auto config for interfaces not manually configured
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ashley = {
    isNormalUser = true;
    description = "Ashley";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # import ZFS pools
  host.zfs.pools = vars.zfs.pools;
  host.zfs.network.hostId = vars.zfs.network.hostId;

  # Host paths
  host.storage.paths = {
    media = "${vars.paths.bulkStorage}/media";
    arrMedia = "${vars.paths.bulkStorage}/arrMedia";
    downloads = "${vars.paths.bulkStorage}/downloads";
    documents = "${vars.paths.bulkStorage}/documents";
    backups = "${vars.paths.bulkStorage}/backups";
  };

  hddSpindown.disks = vars.disksToSpindown;
  intelGraphics.enable = true;
  powersave.enable = true; 
  virtualization.intel.enable = true;

  mediaServer.enable = true;
  mediaServer.vpnConfinement.wireguardConfigFile = ../../secrets/wg-mullvad.conf;
  mediaServer.vpnConfinement.lanSubnet = vars.network.subnet.ipv4;
}
