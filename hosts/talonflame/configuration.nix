# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  deploymentMode = false;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host
  
  networking.hostName = "talonflame";

  deployment.bootstrap.gitClone.host = "talonflame";

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------


  # Use the Linux kernel from nixpkgs-unstable for latest i226 driver

  environment.systemPackages = with pkgs; [
    python3
  ];

  time.timeZone = "Europe/Helsinki";

  # Bootloader
  boot.loader.grub = {
    devices = [ "nodev" ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  users.users.ashley.password = "p@ssuw4d0!2334";


  # -------------------------------- SECRETS --------------------------------

  age.secrets = {

  };


  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = false; # configured in ./homepage-config.nix

  # -------------------------------- Netbird --------------------------------


}
