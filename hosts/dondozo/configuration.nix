# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  mountedPools = {
    bulkStorage = {
      name = "shuurinet-rust";
      path = "/shuurinet-rust";
      driveIds = ["ata-ST16000NM000D-3PC101_ZVTAVSGR" "ata-ST16000NM000D-3PC101_ZVTBH31T"];
    };

    fastStorage = {
      name = "shuurinet-nvme";
      path = "/shuurinet-nvme";
      driveIds = [];
    };

    editingStorage = {
      name = "shuurinet-editing";
      path = "/shuurinet-editing";
      driveIds = [];
    };
  };

  vars.network = {
    interfaces = [ "eno1" "enp2s0f0np0" ]; 
    brige = br0;
  };

  subnet = config.homelab.networks.subnets.bln;
in
{

config = {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/host/drives-filesystems
      ../../modules/host/hardware
      ../../modules/networks.nix
      ../../modules/users-groups
      ../../modules/media-server
    ];  

  # ======== Bootloader ======== 

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  # ======== System ======== 

  time.timeZone = "Europe/Berlin";

  # ======== Networking ======== 

  networking = {
    enable = true;
    hostName = "dondozo";

    bridges.${vars.network.bridge} = {
      interfaces = vars.network.interfaces;
    };

    interfaces.br0 = {
      useDHCP = false; 
      ipv4.addresses = [
        {
          address = "${subnet.ipv4}.10";
          prefixLength = 24;         # Subnet mask (24 = 255.255.255.0)
        }
      ];
      ipv4.gateway = "${subnet.ipv4}.1";

      ipv6.addresses = [
        {
          address = "${subnet.ipv6}::10";
          prefixLength = 64;         # Standard IPv6 subnet prefix length
        }
      ];
      ipv6.gateway = "${subnet.ipv6}::1";
    };

    nameservers = [ "${subnet.ipv4}.1"];
  };

  # ======== Host settings - found in /modules/host ======== 

  host.user.mainUserPassword = pkgs.agenix.decryptFile ./secrets/dondozo-main-user-pw.age;

  # ZFS 
  host.zfs.mountedPools = mountedPools;

  # Storage paths
  host.storage.paths = {
    media = "${mountedPools.bulkStorage.path}/media";
    downloads = "${mountedPools.fastStorage.path}/downloads";
    arrMedia = "${mountedPools.fastStorage.path}/arrMedia";
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
  mediaServer.enableIntelGraphics = true;
};
}