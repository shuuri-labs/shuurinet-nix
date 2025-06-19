# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  system = config.homelab.system;

  hostname = "dondozo";
  hostAddress = "10";
in
{
    imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    # (import ./homepage-config.nix { inherit config; })
    (import ./samba-config.nix { inherit config hostname; })
  ];

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  boot.kernelParams = [ "i915.disable_display=1" ]; # Fix 'EDID block 0 is all zeroes' log spam
  environment.systemPackages = with pkgs; [
    openseachest # seagate disk utils
  ];

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  users.users.ashley.password = "temporary123";

  networking.firewall.allowedTCPPorts = [ 8096 9091 ]; # allow jellyfin & transmission (for now)

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    # System
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.age";

    # Samba Users
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
    home-assistant-backup-samba-user-pw.file = "${secretsAbsolutePath}/samba-home-assistant-backup-password.age";

    # Apps
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad-dondozo.conf.age";
    dondozo-homepage-vars.file = "${secretsAbsolutePath}/dondozo-homepage-vars.age";
    grafana-admin-password = {
      file = "${secretsAbsolutePath}/grafana-admin-password.age";
      owner = "grafana";
      group = "root";
      mode = "440";
    };
    paperless-password.file = "${secretsAbsolutePath}/paperless-password.age";
  
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
  };

  homelab = {
    enable = true;

    domain = {
      sub = "bln";
    };

    system = {
      disk.care = {
        trim.enable = true;
        smartd.disks = [
          { device = "/dev/disk/by-id/ata-CT1000MX500SSD1_2410E89DFB65"; } # boot drive 
          { device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N569313409716"; } # nvme 1
          { device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N569313409716"; } # nvme 1
          { device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N569313409716"; } # nvme 1
          { device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N56931450976D"; } # nvme 2
          { device = "/dev/disk/by-id/ata-ST16000NM000D-3PC101_ZVTAVSGR"; } # HDD 1
          { device = "/dev/disk/by-id/ata-ST16000NM000D-3PC101_ZVTBH31T"; } # HDD 2   
        ];
      };

      storage = {
        paths = {
          bulkStorage = "/shuurinet-rust";
          fastStorage = "/shuurinet-nvme-data";
          editingStorage = "/shuurinet-nvme-editing";
        };
      };
      
      network = {
        hostName = hostname;
        staticIpConfig.enable = true;
        bridges = [
          {
            name = "br0";
            memberInterfaces = [ "enp1s0f1np1" "eno1" ];  
            subnet = system.networks.subnets.bln-lan;
            identifier = hostAddress;
            isPrimary = true;
          }
        ];
      };
    };

    lib = {
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

      uefi.boot.enable = true;
      powersave.enable = true;
      deployment.bootstrap.git.enable = true;

      intel = {
        graphics.enable = true;
      };
      
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
        glances.networkInterfaces = [ "enp1s0f1np1" ];
      };

      monitoring = {
        enable = true;
        grafana.adminPassword = "$__file{${config.age.secrets.grafana-admin-password.path}}";
        prometheus.job_name = hostname;
        loki.hostname = hostname;
      };

      smb.provisioner.enable = true;
      vpnConfinement = {
        wgConfigFile = config.age.secrets.mullvad-wireguard-config.path;
        hostSubnet = {
          ipv4 = system.networks.subnets.bln-lan.ipv4;
          ipv6 = system.networks.subnets.bln-lan.ipv6;
        };
      };
    };

    services = {
      mealie.enable = true;

      mediaServer.enable = true; 

      paperless = {
        enable = true;
        passwordFile = config.age.secrets.paperless-password.path;
      };
    };
  };  
}
