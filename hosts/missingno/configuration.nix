# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  hostAddress = "151";
  deploymentMode = false;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  environment.systemPackages = with pkgs; [
    python3
  ];

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  users.users.ashley.password = "temporary123";

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

    kanidm-admin-password = {
      file = "${secretsAbsolutePath}/kanidm-admin-password.age";
      owner = "kanidm";
      group = "kanidm";
    };
  };


  # -------------------------------- Virtualisation & VMs --------------------------------

  virtualisation = {
    intel.enable = true;
    
    qemu.manager = {
      images = {
        # "openwrt" = {
        #   enable = true;
        #   # openwrt imagebuilder input is pinned to a specific revision to prevent updates upon flake update/rebuild -
        #   # to update the image, see flake.nix openwrt-imagebuilder input
        #   source = inputs.self.packages.${pkgs.system}.berlin-vm-router-img;
        #   sourceFormat = "raw";
        #   compressedFormat = "gz";
        #   # source = "file:///var/lib/vm/images/openwrt-full.qcow2";
        #   # sourceFormat = "qcow2";
        #   # sourceSha256 = "1c2n1qms0prj6chcn7gb169m0fc2692q2nwmah8hv70dla643g7g";
        # };
        
        "haos" = {
          enable = true;
          source = "https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz";
          sourceFormat = "qcow2";
          sourceSha256 = "0jbjajfnv3m37khk9446hh71g338xpnbnzxjij8v86plymxi063d";
          compressedFormat = "xz";
        };
      };

  #     # To 'factory reset VM, delete overlay in "/var/lib/vm/images" and restart service
  #     # VM service names are the names of the service attribute sets below, e.g. "openwrt" or "home-assistant"
      services = {
      #   "openwrt" = {
      #     enable      = true;
      #     baseImage   = "openwrt";
      #     uefi        = true;
      #     memory      = 1024;
      #     smp         = 8;
      #     hostBridges = [ "br0" "br1" ];
      #     pciHosts    = [ 
      #       { address = "03:00.0"; } 
      #       { address = "04:00.0"; }
      #     ];
      #     vncPort   = 1;
      #   };

        "home-assistant" = {
          enable      = true;
          baseImage   = "haos";
          uefi        = true;
          memory      = 3072;
          smp         = 2;
          hostBridges = [ "br0" ];
          rootScsi    = true;
          vncPort     = 2;
        };
      };
    };
  };

  homelab = {
    enable = true;

    common.secrets.sopsKeyPath = "${secretsAbsolutePath}/keys/sops-key.age";

    system = {
      uefi.boot.enable = true;
      disk.care = {
        trim.enable = true;
        smartd.disks = [
          { device = "/dev/disk/by-id/nvme-nvme.1e4b-313132343035303730313731363531-5445414d20544d3846504b30303154-00000001"; } # boot drive
        ];
      };
      
      network = {
        hostName = "missingno";
        staticIpConfig.enable = true;
        bridges = [
          # Management
          {
            name = "br2";
            # memberInterfaces = [ "enp2s0" ];  
            subnet = config.homelab.system.networks.subnets.bln-mngmt;
            identifier = hostAddress;
            isPrimary = deploymentMode; 
          }
          # LAN
          {
            name = "br0";
            memberInterfaces = [ "enp2s0" ];  
            subnet = config.homelab.system.networks.subnets.bln-lan;
            identifier = hostAddress;
            isPrimary = !deploymentMode;
          }
          # Apps
          {
            name = "br1";
          }
        ];
      };
    };

    lib = {
      intel = {
        graphics.enable = true;
        undervolt.enable = true;
      };

      powersave.enable = true;
      
      dns = {
        cloudflare.credentialsFile = config.age.secrets.cloudflare-credentials.path;
      };

      reverseProxy = {
        caddy.environmentFile = config.age.secrets.caddy-cloudflare.path;
      };

      idp = {
        enable = true;
        kanidm = {
          adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
          idmAdminPasswordFile = config.age.secrets.kanidm-admin-password.path;
        };
      };

      dashboard = {
        glances.networkInterfaces = [ "enp2s0" ];
      };
    };

    services = {
      mealie.enable = true;
      mediaServer.enable = true;
      paperless = {
        enable = true;
        passwordFile = config.age.secrets.kanidm-admin-password.path;
      };
    };
  };  
}
