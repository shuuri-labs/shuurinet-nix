# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  # hostCfgVars         = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  hostAddress = "151";
  hostPrimaryIp = "${config.homelab.networks.subnets.bln-lan.ipv4}.${hostAddress}";

  deploymentMode = false;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host
  
  # host.vars = {
  #   network = {
  #     hostName = "missingno";
  #     staticIpConfig.enable = true;
  #     bridges = [
  #       # Management
  #       {
  #         name = "br2";
  #         # memberInterfaces = [ "enp2s0" ];  
  #         subnet = config.homelab.networks.subnets.bln-mngmt;
  #         identifier = hostAddress;
  #         isPrimary = deploymentMode; 
  #       }

  #       # LAN
  #       {
  #         name = "br0";
  #         memberInterfaces = [ "enp3s0" ];  
  #         subnet = config.homelab.networks.subnets.bln-lan;
  #         identifier = hostAddress;
  #         isPrimary = !deploymentMode;
  #       }

  #       # Apps
  #       {
  #         name = "br1";
  #       }
  #     ];
  #   };

  #   storage = {
  #     paths = {
  #       bulkStorage = "/home/ashley";
  #     };
  #   };
  # };

  deployment.bootstrap.gitClone.host = config.homelab.network.hostName;

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
  intel.undervolt.enable = true;
  powersave.enable = true; 

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.agekey.age";

    caddy-cloudflare.file = "${secretsAbsolutePath}/caddy-cloudflare.env.age";

    cloudflare-credentials = {
      file = "${secretsAbsolutePath}/cloudflare-credentials.age";
      owner = "cloudflare-dns";
      group = "cloudflare-dns";
      mode = "440";
    };
  };

  common.secrets.sopsKeyPath = "${secretsAbsolutePath}/keys/sops-key.agekey.age";

  # -------------------------------- DISK CONFIGURATION --------------------------------

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/nvme-nvme.1e4b-313132343035303730313731363531-5445414d20544d3846504b30303154-00000001"; } # boot drive
    ];
  };

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  # homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  # -------------------------------- Virtualisation & VMs --------------------------------

  # virtualisation = {
  #   intel.enable = true;
    
  #   qemu.manager = {
  #     images = {
  #       "openwrt" = {
  #         enable = true;
  #         # openwrt imagebuilder input is pinned to a specific revision to prevent updates upon flake update/rebuild -
  #         # to update the image, see flake.nix openwrt-imagebuilder input
  #         source = inputs.self.packages.${pkgs.system}.berlin-vm-router-img;
  #         sourceFormat = "raw";
  #         compressedFormat = "gz";
  #         # source = "file:///var/lib/vm/images/openwrt-full.qcow2";
  #         # sourceFormat = "qcow2";
  #         # sourceSha256 = "1c2n1qms0prj6chcn7gb169m0fc2692q2nwmah8hv70dla643g7g";
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
  #         enable      = true;
  #         baseImage   = "openwrt";
  #         uefi        = true;
  #         memory      = 1024;
  #         smp         = 8;
  #         hostBridges = [ "br0" "br1" ];
  #         pciHosts    = [ 
  #           { address = "01:00.0"; vendorDeviceId = "8086:1521"; } 
  #           { address = "01:00.1"; }
  #           { address = "01:00.2"; }
  #           { address = "01:00.3"; }
  #         ];
  #         vncPort   = 1;
  #       };

  #       "home-assistant" = {
  #         enable      = true;
  #         baseImage   = "haos";
  #         uefi        = true;
  #         memory      = 3072;
  #         smp         = 2;
  #         hostBridges = [ "br0" ];
  #         rootScsi    = true;
  #         vncPort     = 2;
  #       };
  #     };
  #   };
  # };

  homelab = {
    enable = true;

    network = {
      hostName = "missingno";
      staticIpConfig.enable = true;
      bridges = [
        # Management
        {
          name = "br2";
          # memberInterfaces = [ "enp2s0" ];  
          subnet = config.homelab.networks.subnets.bln-mngmt;
          identifier = hostAddress;
          isPrimary = deploymentMode; 
        }

        # LAN
        {
          name = "br0";
          memberInterfaces = [ "enp3s0" ];  
          subnet = config.homelab.networks.subnets.bln-lan;
          identifier = hostAddress;
          isPrimary = !deploymentMode;
        }

        # Apps
        {
          name = "br1";
        }
      ];
    };

    dns = {
      cloudflare.credentialsFile = config.age.secrets.cloudflare-credentials.path;
      # globalTargetIp = "192.168.11.151";
    };

    reverseProxy = {
      caddy.environmentFile = config.age.secrets.caddy-cloudflare.path;
    };
    
    services = {
      mealie.enable = true;
      jellyfin.enable = true;
    };
  };

  # -------------------------------- Services --------------------------------
  
}