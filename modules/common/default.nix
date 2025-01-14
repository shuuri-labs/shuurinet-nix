{ config, pkgs, lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.common = {
    sshKeys = mkOption {
      type = types.listOf types.str;
      default = 
      [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1TmZx5UfPLkQd583pbMNtlLiq2bH8vnNseYY23zDAdsQDrK5B2oLXFZVHaDeEvg592mUtCxGMXZUaSULizEntyQ82Uszel6aj33Lr3IvEH11eRBv6DjfFZ1SyYRPBqjvh/p4tSRZuqjQ/ZUH52minKCcRouDt978rhSnyIb3Q69CJjn0mBC4JIhXXxueOeKUDagRnieBGlh51VEFSw7nFH+UVep2bEKg3bNgKPBj1J9rWgnp0HB8IGwGuXH0AOyH0CKTUXkhiFbewX5ONCZwdRbvbtp3JE0W7/m4WKHuDN88+yPIAxPqrm9qZFdhiyzrY2Nc/+gO9Y/stApxEID9lcRihgKc1KYJiiLKsmB4fbkuvqXKZRoUIymId0KFCnnHPQUTNjpgy/6Hzfz0TINoS/4CR2uTaO5cUuCqYvPia/ksgeZVMKxGdKZ3CokUDRbHOMREWyqXaooHFv5BjM36UIIv5vyYxViwbfXcuVW3tmsKaUIrr2NYzmtzsN0PSZV0= ashleyamohmensah@Ashleys-MacBook-Pro.local"
      ];
    };
  };

  config = {
    security.sudo.enable = true;

    users.users.ashley = {
      isNormalUser = true;
      description = "Ashley";
      extraGroups = [ "networkmanager" "wheel" ]; # wheel = sudo for nixos
      openssh.authorizedKeys.keys = config.common.sshKeys;
    };

    users.users.root.openssh.authorizedKeys.keys = config.common.sshKeys;

    # Common packages installed on all machines
    environment.systemPackages = with pkgs; [
      curl
      git
      sudo 
      htop
      wget
      util-linux
      age
      wireguard-tools # may or may not be required for vpn confinement module
      pciutils # lspci
      ethtool
      iperf3
    ];

    # Tell agenix which private keys to use for decryption
    age.identityPaths = [
      "/home/ashley/.ssh/id_ed25519"     # User SSH key
      # "/etc/ssh/ssh_host_ed25519_key"          # Host SSH key
    ];

    # Common services
    services.openssh.enable = true;

    # Enable automatic usage of generated ssh keys
    programs.ssh.startAgent = true;

    # Enable unfree packages
    nixpkgs.config.allowUnfree = true;

    # enable vscode connection
    services.vscode-server.enable = true;

    # add ssh auth keys for root user and 'ashley' use

    # enable nix flakes
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # set version
    system.stateVersion = "24.11";

    # enable firewall
    networking.firewall.enable = true; 

    # system locale settings
    i18n.defaultLocale = "en_GB.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_GB.UTF-8";
      LC_IDENTIFICATION = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_MONETARY = "en_GB.UTF-8";
      LC_NAME = "en_GB.UTF-8";
      LC_NUMERIC = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_TELEPHONE = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };

    # system keyboard layout
    services.xserver.xkb = {
      layout = "gb";
      variant = "";
    };
    console.keyMap = "uk";

    # may or may not be required for vpn confinement module.
    networking.wireguard.enable = true;  
  };
}