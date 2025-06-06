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
  networking.interfaces.eth0.useDHCP = true;
  boot.kernelParams = ["net.ifnames=0"];

  deployment.bootstrap.gitClone.host = "talonflame";

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  environment.systemPackages = with pkgs; [
    python3
  ];

  time.timeZone = "Europe/Helsinki";

  # Bootloader
  boot.loader.grub = {
    enable = true;
    device = "nodev";
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
