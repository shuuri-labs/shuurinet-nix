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
  ];

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host

  host.vars = {
    network = {
      config = {
        hostName = "ludicolo";
        interfaces = [ "enp1s0" ];
        bridge = "br0";
        unmanagedInterfaces = config.host.vars.network.config.interfaces ++ [ config.host.vars.network.config.bridge ];
        subnet = config.homelab.networks.subnets.ldn; # see /options-homelab/networks.nix 
        hostIdentifier = "10";
      };

      staticIpConfig.enable = true;
    };

    storage = {
      paths = {
        bulkStorage = "/gennai-rust";
      };
    };
  };

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  time.timeZone = "Europe/London";

  # Bootloader
  host.uefi-boot.enable = true;

  users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  
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
        name = "gennai-rust";
        autotrim = false;
      };
    
    };
    network.hostId = "b4d8f29e";
  };

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/ata-SAMSUNG_MZ7LN256HMJP-000H1_S2Y9NB0J629446"; } # boot drive
      { device = "/dev/disk/by-id/wwn-0x5000c500be81301d"; } # HDD 1
    ];
  };

 # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  monitoring = {
    enable = true;
    grafana.adminPassword = "$__file{${config.age.secrets.grafana-admin-password.path}}";
    prometheus.job_name = "ludicolo";
    loki.hostname = "ludicolo";
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
}