# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  vars = {
    network = {
      hostName = "castform";
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

  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 
in
{
  imports = [
    ./hardware-configuration.nix
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
    hostName = vars.network.hostName;

    useNetworkd = true;
    enableIPv6 = true;

    # Bridge Definition
    bridges.${vars.network.bridge} = {
      interfaces = vars.network.interfaces;
    };

    # bridge interface config
    interfaces."${vars.network.bridge}" = {
      ipv4 = {
        addresses = [{
          address = vars.network.hostAddress;
          prefixLength = 24;
        }];
      };

      ipv6 = {
        addresses = [{
          address = vars.network.hostAddress6; 
          prefixLength = 64;
        }];
      };
    };

    # Default Gateways
    defaultGateway = {
      address = vars.network.subnet.gateway;
      interface = vars.network.bridge;
    };

   defaultGateway6 = {
     address = vars.network.subnet.gateway6;
     interface = vars.network.bridge;
   };

    # Nameservers
    nameservers = [ 
      vars.network.subnet.gateway
      # vars.network.subnet.gateway6 # doesn't seem to be needed, might break if added!
    ];

    # Required for automatic management of interfaces not configured above, including wireguard interfaces
    networkmanager.enable = true;
  };

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  
  age.secrets = {
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";

    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad.conf.age"; # TODO: check if vpn-confinement needs .conf file, use this instead if not
    
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
  };

  # set a unique main user pw (main user created in common module)
  users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;

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

  # Media Server
  mediaServer.enable = true;
  mediaServer.vpnConfinement.wireguardConfigFile = config.age.secrets.mullvad-wireguard-config.path; 
  mediaServer.vpnConfinement.lanSubnet = vars.network.subnet.ipv4;
  mediaServer.vpnConfinement.lanSubnet6 = vars.network.subnet.ipv6;

  mediaServer.paths.media = config.host.storage.paths.media;
  mediaServer.paths.arrMedia = config.host.storage.paths.arrMedia;
  mediaServer.paths.mediaGroup = config.host.accessGroups.media.name;

  mediaServer.services.downloadDir = config.host.storage.paths.downloads; 
  mediaServer.services.downloadDirAccessGroup = config.host.accessGroups.downloads.name;
  mediaServer.services.mediaDirAccessGroup = config.host.accessGroups.media.name;
  mediaServer.services.arrMediaDirAccessGroup = config.host.accessGroups.arrMedia.name;

  # Samba
  sambaProvisioner.enable = true;
  sambaProvisioner.hostName = vars.network.hostName;
  sambaProvisioner.users = [
    { name = "ashley"; 
      passwordFile = config.age.secrets.ashley-samba-user-pw.path; 
    }
    { 
      name = "media"; 
      passwordFile = config.age.secrets.media-samba-user-pw.path; 
      createHostUser = true; # samba needs a user to exist for the samba users to be created
      extraGroups = [ "mediaDirAccess" "arrMediaDirAccess" ]; 
    } 
  ];

  services.samba.settings = {
    castform-rust = {
      browseable = "yes";
      comment = "Castform Rust Pool";
      "guest ok" = "no";
      path = "/castform-rust";
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley media"; # todo: dynamic based on user definitions above
    };
  };
}
