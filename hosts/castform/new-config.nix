# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  vars.network = {
    interfaces = [ "enp0s31f6" ]; 
    bridge = "br0";

    subnet = config.homelab.networks.subnets.bln;

    hostAddress = "${vars.network.subnet.ipv4}.121";
    hostAddress6 = "${vars.network.subnet.ipv6}::121";
  };
in
{
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/networks.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "castform";
    hostId = "c8f36183";

    # Bridge Definition
    bridges.${vars.network.bridge} = {
      interfaces = vars.network.interfaces;
    };

    # bridge interface config
    interfaces."${vars.network.bridge}" = {
      useDHCP = false;

      ipv4 = {
        addresses = [{
          address = vars.network.hostAddress;
          prefixLength = 24;
        }];
      };

      ipv6 = {
        addresses = [{
          address = vars.network.hostAddress6;  # Ensure proper IPv6 formatting
          prefixLength = 64;
        }];
      };
    };

    # Default Gateways
    defaultGateway = {
      address = "${vars.network.subnet.ipv4}.1";
      interface = vars.network.bridge;
    };

    defaultGateway6 = {
      address = "${vars.network.subnet.ipv6}::1";
      interface = vars.network.bridge;
    };

    # Nameservers
    nameservers = [ 
      "${vars.network.subnet.ipv4}.1" 
      "${vars.network.subnet.ipv6}::1"
    ];
  };

  # Enable networking auto config for interfaces not manually configured
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ashley = {
    isNormalUser = true;
    description = "Ashley";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };
}
