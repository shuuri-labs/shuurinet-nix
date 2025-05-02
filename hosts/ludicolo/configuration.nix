# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, lib, ... }:

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
      hostName = "ludicolo";
      staticIpConfig.enable = true;
      bridges = [
        {
          name = "br0";
          memberInterfaces = [ "enp1s0" ];  
          subnet = config.homelab.networks.subnets.ldn;
          identifier = "10";
          isPrimary = true;
        }
      ];
    };

    storage = {
      paths = {
        bulkStorage = "/gennai-rust";
      };
    };
  };

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  # Realtek 8168/8111/8169 NICs - blacklist r8169 driver and enable r8168 driver
  
  # boot.kernelPackages =lib.mkForce pkgs.linuxPackages_6_1;
  # boot.extraModulePackages = [ config.boot.kernelPackages.r8168 ];
  # boot.kernelModules = [ "r8168" ];
  # boot.blacklistedKernelModules = [ "r8169" ];
  # nixpkgs.config.allowBroken = true;

  time.timeZone = "Europe/London";

  # Bootloader
  host.uefi-boot.enable = true;

  # users.users.ashley.password = "changeme"; /* uncomment for new install */
  users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path; # TODO: use plain hashed password file

  environment.systemPackages = with pkgs; [
    dig
  ];
  
  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad-ludicolo.conf.age";
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
    ludicolo-homepage-vars.file = "${secretsAbsolutePath}/ludicolo-homepage-vars.age";
    netbird-management-url.file = "${secretsAbsolutePath}/netbird-management-url.age";
    ludicolo-netbird-master-setup-key.file = "${secretsAbsolutePath}/ludicolo-netbird-master-setup-key.age";
    
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

  # (jellyfin metadata) ldn ipv6 tunnel (Hurricane Electric) can't connect to themoviedb.org via its
  # (default) IPv6 DNS record for some reason, so fetch IPv4 address and update hosts file to force IPv4
  systemd.services.update-themoviedb-ip = {
    description = "Update themoviedb.org IP address in hosts file";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "update-themoviedb-ip" ''
        IP=$(${pkgs.dig}/bin/dig +short themoviedb.org | head -n1)
        if [ -n "$IP" ]; then
          sed -i '/themoviedb.org/d' /etc/hosts
          echo "$IP themoviedb.org api.themoviedb.org" >> /etc/hosts
        fi
      '';
    };
  };

  systemd.timers.update-themoviedb-ip = {
    wantedBy = [ "multi-user.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1h";
    };
  };

  # -------------------------------- FRIGATE --------------------------------

  frigate = {
    enable = true;
    host.nvrMediaStorage = "${hostCfgVars.storage.paths.bulkStorage}/nvr";
    mainUser = "ashley";
    configFile = builtins.readFile ./frigate/config.yml;
  };

  # -------------------------------- Virtualisation & VMs --------------------------------

  virtualization = {
    intel.enable = true;
  };

  # -------------------------------- VPNs & REMOTE ACCESS --------------------------------

  netbird.router = {
    enable = true;
    hostInterface = hostCfgVars.network.config.bridge;
    hostSubnet = hostCfgVars.network.config.subnet.ipv4;
    managementUrlPath = config.age.secrets.netbird-management-url.path;
    
    peers = {
      master = {
        enable = lib.mkForce true;
        setupKey = config.age.secrets.ludicolo-netbird-master-setup-key.path;
      };
    };
  };
}