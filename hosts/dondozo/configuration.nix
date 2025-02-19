# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

let
  hostCfgVars = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./homepage-config.nix 
    ./samba-config.nix
  ];

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host


  host.vars = {
    network = {
      config = {
        hostName = "dondozo";
        interfaces = [ "enp2s0f1np1" "eno1"];
        bridge = "br0";
        unmanagedInterfaces = config.host.vars.network.config.interfaces ++ [ config.host.vars.network.config.bridge "eno2" ];
        subnet = config.homelab.networks.subnets.bln; # see /options-homelab/networks.nix 
        hostIdentifier = "10";
        hostAddress6 = "${config.host.vars.network.config.subnet.ipv6}:${config.host.vars.network.config.hostIdentifier}";
      };

      staticIpConfig.enable = true;
    };

    storage = {
      paths = {
        bulkStorage = "/shuurinet-rust";
        fastStorage = "/shuurinet-nvme-data";
        editingStorage = "/shuurinet-nvme-editing";
      };
    };
  };

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;

  environment.systemPackages = with pkgs; [
    openseachest
  ];
  
  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad.conf.age";
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
    dondozo-homepage-vars.file = "${secretsAbsolutePath}/dondozo-homepage-vars.age";
    
    grafana-admin-password = {
      file = "${secretsAbsolutePath}/grafana-admin-password.age";
      owner = "grafana";
      group = "root";
      mode = "440";
    };

    paperless-password.file = "${secretsAbsolutePath}/paperless-password.age";
    home-assistant-backup-samba-user-pw.file = "${secretsAbsolutePath}/samba-home-assistant-backup-password.age";
  };

  # -------------------------------- DISK CONFIGURATION --------------------------------

  zfs = {
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
    network.hostId = "45072e28";
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

 # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  monitoring = {
    enable = true;
    grafana.adminPassword = "$__file{${config.age.secrets.grafana-admin-password.path}}";
    prometheus.job_name = "dondozo";
    loki.hostname = "dondozo";
  };

  # -------------------------------- HARDWARE FEATURES --------------------------------

  # Intel-specific & Power Saving
  intelGraphics.enable = true;
  powersave.enable = true; 
  virtualization.intel.enable = true;

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

  # paperless-ngx
  paperless-ngx = {
    enable = true;
    passwordFile = config.age.secrets.paperless-password.path;
    documentsDir = config.host.vars.storage.directories.documents;
    documentsAccessGroup = config.host.vars.storage.accessGroups.documents.name;
    hostMainStorageUser = "ashley";
  };
}