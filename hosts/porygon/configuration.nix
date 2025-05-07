# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  hostCfgVars         = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  hostAddress = "214";
  hostPrimaryIp = "${config.homelab.networks.subnets.ldn.ipv4}.${hostAddress}";

  deploymentMode = false;
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
      hostName = "porygon";
      staticIpConfig.enable = true;
      bridges = [
        # LAN
        {
          name = "br0";
          memberInterfaces = [ "enp2s0" ];  
          subnet = config.homelab.networks.subnets.ldn;
          identifier = hostAddress;
          isPrimary = !deploymentMode;
          tapDevices = [ "opnwrt-tap" "haos-tap" ];
        }

        # Apps
        {
          name = "br1";
          tapDevices = [ "opnwrt-apps-tap" ];
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

  boot.kernelParams = [
    "pcie_aspm=force"
    "pcie_aspm.policy=powersave"
  ];

  # Use the Linux kernel from nixpkgs-unstable for latest i226 driver
  boot.kernelPackages = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.linuxPackages_latest;

  environment.systemPackages = with pkgs; [
    python3
  ];

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  users.users.ashley.password = "temporary123";

  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024; # 16GB
  }];

  # -------------------------------- HARDWARE CONFIGURATION --------------------------------

  # Intel-specific & Power Saving
  intel.graphics.enable = true;
  powersave.enable = true; 

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.agekey.age";
    netbird-management-url.file = "${secretsAbsolutePath}/netbird-management-url.age";

    obsd-couchdb-config = {  
      file = "${secretsAbsolutePath}/obsd-couchdb-config.ini.age";
      owner = "couchdb";
      group = "couchdb";
    };
  };

  # -------------------------------- DISK CONFIGURATION --------------------------------

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/ata-WDC_WDS120G2G0A-00JH30_192275800224"; } # boot drive
    ];
  };

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  # -------------------------------- Virtualisation & VMs --------------------------------

  # virtualisation = {
  #   intel.enable = true;
    
  #   qemu.manager = {
  #     images = {
  #       "openwrt" = {
  #         enable = true;
  #         # openwrt imagebuilder input is pinned to a specific revision to prevent updates upon flake update/rebuild -
  #         # to update the image, see flake.nix openwrt-imagebuilder input
  #         source = inputs.self.packages.${pkgs.system}.london-test-router-img;
  #         sourceFormat = "raw";
  #         compressedFormat = "gz";
  #       };
        
  #       "haos" = {
  #         enable = true;
  #         source = "https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz";
  #         sourceFormat = "qcow2";
  #         sourceSha256 = "0jbjajfnv3m37khk9446hh71g338xpnbnzxjij8v86plymxi063d";
  #         compressedFormat = "xz";
  #       };
  #     };

  #     # To 'factory reset VM, delete overlay in "/var/lib/vm/images" and restart service
  #     # VM service names are the names of the service attribute sets below, e.g. "openwrt" or "home-assistant"
  #     services = {
  #       "openwrt" = {
  #         enable     = true;
  #         baseImage  = "openwrt";
  #         uefi       = true;
  #         memory     = 512;
  #         smp        = 8;
  #         taps       = [ 
  #           { name = "opnwrt-tap";      macAddress = "fe:b5:aa:0f:29:43"; }
  #           { name = "opnwrt-apps-tap"; macAddress = "fe:b5:aa:0f:29:44"; }
  #         ];
  #         bridges    = [ "br0" "br1" ];
  #         vncPort   = 1;
  #       };

  #       "home-assistant" = {
  #         enable     = true;
  #         baseImage  = "haos";
  #         uefi       = true;
  #         memory     = 3072;
  #         smp        = 2;
  #         taps       = [ 
  #           { name = "haos-tap"; macAddress = "ce:b0:37:6c:1a:fd"; }
  #         ];
  #         bridges    = [ "br0" ];
  #         rootScsi   = true;
  #         vncPort    = 2;
  #       };
  #     };
  #   };
  # };

  ### OpenWrt Config Auto-Deploy
  # openwrt.config-auto-deploy = {
  #   enable = true;
  #   sopsAgeKeyFile = config.age.secrets.sops-key.path;

  #   configs = {
  #     vm-test-router-config = {
  #       drv = inputs.self.packages.${pkgs.system}.vm-test-router-config;
  #       imageDrv = inputs.self.packages.${pkgs.system}.berlin-router-img;
  #       serviceName = "openwrt";
  #       host = "10.11.20.51";
  #     };  
  #   };
  # };

  ### Containers
  netbird.router = {
    enable = true;
    
    managementUrlPath = config.age.secrets.netbird-management-url.path;
    
    # peers = {
    #   master = {
    #     enable = lib.mkForce true;
    #     setupKey = config.age.secrets.missingno-netbird-master-setup-key.path;
    #     hostInterface = "br0";
    #     hostSubnet = config.homelab.networks.subnets.bln-lan.ipv4;
    #   };

    #   apps = {
    #     enable = lib.mkForce true;
    #     setupKey = config.age.secrets.missingno-netbird-apps-setup-key.path;
    #     hostSubnet = config.homelab.networks.subnets.bln-apps.ipv4; 
    #   };
    # };
  };

  # -------------------------------- Services --------------------------------

  ### Obsidian Livesync
  services.couchdb = {
    enable = true;
    configFile = config.age.secrets.obsd-couchdb-config.path;
    bindAddress = hostPrimaryIp;
  };

  networking.firewall = {
    allowedTCPPorts = [ 5984 ];
  };
}