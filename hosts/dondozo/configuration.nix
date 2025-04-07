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
      };

      staticIpConfig = {
        enable = true;
        enableSourceRouting = false;
        unmanagedInterfaces = [ "eno2" ];

        bridges = [{
          name = "br0";
          identifier = "10";
          bridgedInterfaces = [ "enp2s0f1np1" "eno1" ];
          subnetIpv4 = homelabNetworks.bln.ipv4;
          subnetIpv6 = homelabNetworks.bln.ipv6;
          isPrimary = true;
        }];
      };
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
    openseachest # seagate disk utils
  ];

  boot.kernelParams = [ "i915.disable_display=1" ]; # Fix 'EDID block 0 is all zeroes' log spam
  
  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad-dondozo.conf.age";
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
      { device = "/dev/disk/by-id/ata-CT1000MX500SSD1_2410E89DFB65"; } # boot drive 
      { device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N569313409716"; } # nvme 1
      { device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N569313409716"; } # nvme 1
      { device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N569313409716"; } # nvme 1
      { device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N56931450976D"; } # nvme 2
      { device = "/dev/disk/by-id/ata-ST16000NM000D-3PC101_ZVTAVSGR"; } # HDD 1
      { device = "/dev/disk/by-id/ata-ST16000NM000D-3PC101_ZVTBH31T"; } # HDD 2
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

  # -------------------------------- FILE SERVER --------------------------------

  # Samba - configured in ./samba-config.nix
  sambaProvisioner.enable = true;

  # -------------------------------- HOSTED SERVICES --------------------------------

  # Media Server
  mediaServer.enable = true;
  mediaServer.vpnConfinement.wireguardConfigFile = config.age.secrets.mullvad-wireguard-config.path; 
  mediaServer.vpnConfinement.lanSubnet = hostCfgVars.network.config.subnet.ipv4;
  mediaServer.vpnConfinement.lanSubnet6 = hostCfgVars.network.config.subnet.ipv6;

  mediaServer.storage.path = hostCfgVars.storage.directories.media;
  mediaServer.storage.group = hostCfgVars.storage.accessGroups.media.name;
  mediaServer.storage.hostMainStorageUser = "ashley";

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

  # -------------------------------- VIRTUALISATION --------------------------------
  
  virtualization = {
    intel.enable = true;
    nixvirt = {
      enable = true;
      pools.main = {
        uuid = "06ac9a66-074f-4308-a7b1-74897a81dea3";
        images.path = "/var/lib/vms/images";
      };
    };
  };

}