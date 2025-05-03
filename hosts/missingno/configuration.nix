# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  hostCfgVars         = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  undervoltConfig = ''
    undervolt 0 'CPU' -125.00
    undervolt 1 'GPU' 0.00
    undervolt 2 'CPU Cache' -125.00
    undervolt 3 'System Agent' -30.00
    undervolt 4 'Analog I/O' 0.00
  '';
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
      hostName = "missingno";
      staticIpConfig.enable = true;
      bridges = [
        {
          name = "br0";
          memberInterfaces = [ "enp2s0" "enp1s0f0" ];  
          subnet = config.homelab.networks.subnets.bln;
          identifier = "151";
          isPrimary = true;
          tapDevices = [ "openwrt-tap" "haos-tap" ];
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

  environment.systemPackages = with pkgs; [
    python3
    acpica-tools
    intel-undervolt
  ];

  systemd.services.intel-undervolt-config = {
    description = "Write and apply intel-undervolt config";
    before = [ "intel-undervolt.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.writeShellScript "write-intel-undervolt-conf" ''
          echo "${undervoltConfig}" > /etc/intel-undervolt.conf
          chmod 644 /etc/intel-undervolt.conf
          ${pkgs.intel-undervolt}/bin/intel-undervolt apply
        ''}
      '';
    };
  };

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  # users.users.ashley.password = "temporary123";

  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024; # 16GB
  }];

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.agekey.age";

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
      { device = "/dev/disk/by-id/ata-SanDisk_SDSSDH3_250G_214676446013"; } # boot drive
    ];
  };

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  # -------------------------------- HARDWARE FEATURES --------------------------------

  # Intel-specific & Power Saving
  intelGraphics.enable = true;
  powersave.enable = true; 

  # -------------------------------- Virtualisation & VMs --------------------------------

  users.users.ashley.extraGroups = [ "libvirtd" ];

  virtualization = {
    intel.enable = true;
  };

  virtualisation.qemu.manager = {
    images = {
      "openwrt" = {
        enable = true;
        source = inputs.self.packages.${pkgs.system}.berlin-router-img;
        sourceFormat = "raw";
        compressedFormat = "gz";
      };
      
      "haos" = {
        enable = true;
        source = "https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz";
        sourceFormat = "qcow2";
        sourceSha256 = "0jbjajfnv3m37khk9446hh71g338xpnbnzxjij8v86plymxi063d";
        compressedFormat = "xz";
      };
    };

    # To 'factory reset VM, delete overlay in "/var/lib/vm/images" and stop/start service!
    # VM service names are the names of the service attribute sets below, e.g. "openwrt" or "home-assistant"
    services = {
      "openwrt" = {
        enable    = true;
        baseImage = "openwrt";
        uefi      = true;
        memory    = 1024;
        smp       = 8;
        taps      = [ "openwrt-tap" ];
        bridges   = [ "br0" ];
        pciHosts  = [ 
          { address = "01:00.0"; vendorDeviceId = "8086:150e"; } 
          { address = "01:00.1"; }
          { address = "01:00.2"; }
          { address = "01:00.3"; }
        ];
        vncPort   = 1;
      };

      "home-assistant" = {
        enable     = true;
        baseImage  = "haos";
        uefi       = true;
        memory     = 3072;
        smp        = 2;
        taps       = [ "haos-tap" ];
        bridges    = [ "br0" ];
        rootScsi   = true;
        vncPort    = 2;
      };
    };
  };

  openwrt.config-auto-deploy = {
    enable = true;
    sopsAgeKeyFile = config.age.secrets.sops-key.path;

    configs = {
      vm-test-router-config = {
        drv = inputs.self.packages.${pkgs.system}.vm-test-router-config;
        serviceName = "openwrt";
      };  
    };
  };

  # -------------------------------- Services --------------------------------

  ### Obsidian Livesync
  services.couchdb = {
    enable = true;
    configFile = config.age.secrets.obsd-couchdb-config.path;
    bindAddress = "0.0.0.0";
  };

  networking.firewall = {
    allowedTCPPorts = [ 5984 ];
  };
}
