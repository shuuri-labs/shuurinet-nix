# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  vars = {
    network = {
      hostName = "dondozo";
      interfaces = [ "enp2s0f1np1" "eno1"];
      bridge = "br0";
      unmanagedInterfaces = vars.network.interfaces ++ [ vars.network.bridge "eno2" ];
      
      subnet = config.homelab.networks.subnets.bln;

      hostAddress = "${vars.network.subnet.ipv4}.10";
      hostAddress6 = "${vars.network.subnet.ipv6}::10";
    };

    zfs = {
      network.hostId = "45072e28"; 

      pools = {
        rust = {
          name = "shuurinet-rust";
          autotrim = false;
        };
        nvmeData = {
          name = "shuurinet-nvme-data";
          autotrim = true;
        };
        nvmeEditing = {
          name = "shuurinet-nvme-editing";
          autotrim = true;
        };
      };
    };

    paths = {
      bulkStorage = "/shuurinet-rust";
      fastStorage = "/shuurinet-nvme-data";
      editingStorage = "/shuurinet-nvme-editing";
    };

    # disksToSpindown = [ "ata-ST16000NM000D-3PC101_ZVTAVSGR" "ata-ST16000NM000D-3PC101_ZVTBH31T" ];
  };

  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
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
    arrMedia = "${vars.paths.fastStorage}/media";
    downloads = "${vars.paths.fastStorage}/downloads";
    documents = "${vars.paths.fastStorage}/documents";
    backups = "${vars.paths.fastStorage}/backups";
    editing = "${vars.paths.editingStorage}/editing";
  };

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      {
        device = "/dev/disk/by-id/ata-CT1000MX500SSD1_2410E89DFB65"; # boot drive
      }
      {
        device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N569313409716"; # nvme 1
      }
      {
        device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N56931450976D"; # nvme 2
      }
      {
        device = "/dev/disk/by-id/ata-ST16000NM000D-3PC101_ZVTAVSGR"; # HDD 1
      }
      {
        device = "/dev/disk/by-id/ata-ST16000NM000D-3PC101_ZVTBH31T"; # HDD 2
      }
    ];
  };

  # hddSpindown.disks = vars.disksToSpindown;
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
  sambaProvisioner.hostIp = "${vars.network.hostAddress}/32";
  sambaProvisioner.users = [
    { name = "ashley"; 
      passwordFile = config.age.secrets.ashley-samba-user-pw.path; 
    }
    { 
      name = "media"; 
      passwordFile = config.age.secrets.media-samba-user-pw.path; 
      createHostUser = true; # samba needs a user to exist for the samba users to be created
      extraGroups = [ config.host.accessGroups.media.name config.host.accessGroups.arrMedia.name ]; 
    } 
  ];

  services.samba.settings = {
    shuurinet-rust = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = vars.paths.bulkStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    shuurinet-data = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = vars.paths.fastStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    shuurinet-editing = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = vars.paths.editingStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    media = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = "${vars.paths.bulkStorage}/media";
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley media"; 
    };
  };

  services.homepage-dashboard.widgets =
  [{
    resources = {
      cpu = true;
      disk = [ "/" "/shuurinet-rust" "/shuurinet-nvme-data" "/shuurinet-nvme-editing" ];
      memory = true;
      units = "metric";
      uptime = true;
    };
  }
  {
    search = {
      provider = "duckduckgo";
      target = "_blank";
    };
  }];
}
