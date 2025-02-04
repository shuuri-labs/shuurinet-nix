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
      unmanagedInterfaces = vars.network.interfaces ++ [ vars.network.bridge ];

      subnet = config.homelab.networks.subnets.bln;

      hostAddress = "${vars.network.subnet.ipv4}.121";
      hostAddress6 = "${vars.network.subnet.ipv6}::121";
    };

    zfs = {
      network.hostId = "c8f36183"; 

      pools = {
        rust = {
          name = "castform-rust";
          autotrim = false;
        };
      };
    };

    paths = {
      bulkStorage = "/castform-rust";
    };

    disksToSpindown = [ "ata-WDC_WD10EZEX-07WN4A0_WD-WCC6Y3ESH5SP" ];
  };

  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  # Networking
  host.staticIpNetworkConfig = {
    networkConfig = vars.network;
  };

  age.secrets = {
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad.conf.age";
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad.conf.age";
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
  };

  # set a unique main user pw (main user created in common module)
  users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;

  # import ZFS pools
  host.zfs.pools = vars.zfs.pools;
  host.zfs.network.hostId = vars.zfs.network.hostId;

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      {
        device = "/dev/disk/by-id/ata-SanDisk_SDSSDH3_250G_214676446013"; # boot drive
      }
      {
        device = "/dev/disk/by-id/ata-WDC_WD10EZEX-07WN4A0_WD-WCC6Y3ESH5SP"; # drive 1
      }
    ];
  };

  # Host paths
  host.storage.paths = {
    media = "${vars.paths.bulkStorage}/media";
    downloads = "${vars.paths.bulkStorage}/downloads";
    documents = "${vars.paths.bulkStorage}/documents";
    backups = "${vars.paths.bulkStorage}/backups";
  };

  hddSpindown.disks = vars.disksToSpindown;
  intelGraphics.enable = true;
  intelGraphics.i915.guc_value = "2";
  powersave.enable = true; 
  virtualization.intel.enable = true;

  # Media Server
  mediaServer.enable = true;
  mediaServer.vpnConfinement.wireguardConfigFile = config.age.secrets.mullvad-wireguard-config.path; 
  mediaServer.vpnConfinement.lanSubnet = vars.network.subnet.ipv4;
  mediaServer.vpnConfinement.lanSubnet6 = vars.network.subnet.ipv6;

  mediaServer.mediaDir = config.host.storage.paths.media;
  mediaServer.mediaGroup = config.host.storage.accessGroups.media.name;
  mediaServer.hostMainStorageUser = "ashley";
  
  mediaServer.services.downloadDir = config.host.storage.paths.downloads; 
  mediaServer.services.downloadDirAccessGroup = config.host.storage.accessGroups.downloads.name;
  mediaServer.services.mediaDirAccessGroup = config.host.storage.accessGroups.media.name;

  # Samba
  sambaProvisioner.enable = true;
  sambaProvisioner.hostName = vars.network.hostName;
  sambaProvisioner.hostIp = "${vars.network.hostAddress}/32";
  sambaProvisioner.users = [
    { name = "ashley"; 
      passwordFile = config.age.secrets.ashley-samba-user-pw.path; 
    }
    { 
      name = "media"; 
      passwordFile = config.age.secrets.media-samba-user-pw.path; 
      createHostUser = true; # samba needs a user to exist for the samba users to be created
      extraGroups = [ config.host.storage.accessGroups.media.name ]; 
    } 
  ];

  services.samba.settings = {
    castform-rust = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = vars.paths.bulkStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley media"; # todo: dynamic based on user definitions above
    };
  };
}
