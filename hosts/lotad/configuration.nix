# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, secretsPath, ... }:

let
  mountedPools = {
    bulkStorage = {
      name = "lotad-rust";
      path = "/lotad-rust";
      driveIds = [ ];
    };

    fastStorage = {
      name = "lotad-rust";
      path = "/lotad-rust";
      driveIds = [];
    };

    editingStorage = {
      name = "lotad-rust";
      path = "/lotad-rust";
      driveIds = [];
    };
  };

  vars.network = {
    interface = "enp0s31f6";
    interfaces = [ "enp0s31f6" ]; 
    bridge = "br0";
  };

  subnet = config.homelab.networks.subnets.ldn;

  hostname = "nixos";

  # age.secrets.dondozo-main-user-pw = {
  #   file = "${secretsPath}/dondozo-main-user-pw.age";
  # };

  hostAddress = "${subnet.ipv4}.50";
  hostAddress6 = "${subnet.ipv6}::50";
in
{
  imports =
  [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/host/drives-filesystems
    ../../modules/host/hardware/intel-graphics.nix
    ../../modules/host/hardware/intel-virtualisation.nix
    ../../modules/host/hardware/power-saving.nix
    ../../modules/networks.nix
    ../../modules/media-server
  ];  

  config = {
    # ======== Bootloader ======== 
    
    boot.loader.grub = {
      enable = true;
      device = [ "nodev"];
      useOSProber = true;
    };

    # ======== System ======== 

    time.timeZone = "Europe/Berlin";

    # ======== Networking ======== 

    networking = {
      hostName = hostname;
      hostId = "b4f8d231";

      useDHCP = false;

      # Bridge Definition
      bridges.${vars.network.bridge} = {
        interfaces = vars.network.interfaces;
      };

      # bridge interface config
      interfaces."${vars.network.bridge}" = {
        ipv4 = {
          addresses = [{
            address = hostAddress;
            prefixLength = 24;
          }];
        };

        ipv6 = {
          addresses = [{
            address = hostAddress6;  # Ensure proper IPv6 formatting
            prefixLength = 64;
          }];
        };
      };

      # Default Gateways
      defaultGateway = {
        address = "${subnet.ipv4}.1";
        interface = vars.network.interface;
      };

      defaultGateway6 = {
        address = "${subnet.ipv6}::1";
        interface = vars.network.interface;
      };

      # Nameservers
      nameservers = [ "${subnet.ipv4}.1" ];
    };

    # ======== Host settings - found in /modules/host ======== 

    age.secrets.dondozo-main-user-pw = {
      file = "${secretsPath}/dondozo-main-user-pw.age";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    host.user.mainUserPassword = config.age.secrets.dondozo-main-user-pw.path;
    host.user.sshKeys = config.common.sshKeys;


    # ZFS 
    host.zfs.mountedPools = mountedPools;

    # Storage paths
    host.storage.paths = {
      media = "${mountedPools.bulkStorage.path}/media";
      downloads = "${mountedPools.fastStorage.path}/downloads";
      documents = "${mountedPools.fastStorage.path}/documents";
      backups = "${mountedPools.fastStorage.path}/backups";
    };

    host.hddSpindown.disksToSpindown = mountedPools.bulkStorage.driveIds;
    host.virtualization.enable = true;
    host.intelGraphics.enable = true;
    host.powersave.enable = true;
    
    # ======== Applications and Services ======== 

    # Media Server
    mediaServer.enable = true;
    mediaServer.container.network.interfaceExternal = vars.network.bridge;
    mediaServer.container.network.hostAddress = hostAddress;
    mediaServer.container.network.hostAddress6 = hostAddress6;
  };
}