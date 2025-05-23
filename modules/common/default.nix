{ config, pkgs, lib, stateVersion, ... }:

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

    secrets.sopsKeyPath = mkOption {
      type = types.str;
      default = "";
    };
  };

  config = {
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    system.stateVersion = stateVersion;

    security.sudo.enable = true;

    services.openssh = {
      enable = true;
      # PasswordAuthentication = false;
      settings.PermitRootLogin = "no";
    };

    # Enable automatic usage of generated ssh keys
    programs.ssh.startAgent = true;

    users = {
      users.root.openssh.authorizedKeys.keys = config.common.sshKeys;

      users.ashley = {
        isNormalUser = true;
        description = "Ashley";
        group = "ashley";
        extraGroups = [ "networkmanager" "wheel" ]; # wheel = sudo for nixos
        openssh.authorizedKeys.keys = config.common.sshKeys;
        uid = 1000;
      };

      groups.ashley = {
        gid = 985;
      };
    };

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

    networking.firewall.enable = true; 

    environment.systemPackages = with pkgs; [
      tmux
      neofetch
      curl
      git
      sudo 
      htop
      iotop
      wget
      util-linux
      age
      sops
      wireguard-tools
      pciutils # lspci
      ethtool
      sysstat
    ];

    # Tell agenix which private keys to use for decryption
    age.identityPaths = [
      "/home/ashley/.ssh/id_ed25519"    # User SSH key
      "/etc/ssh/ssh_host_ed25519_key"   # Host SSH key, does not work with agenix
    ];
    
    environment.variables.SOPS_AGE_KEY_FILE = config.common.secrets.sopsKeyPath;
    
    # enable vscode connection
    services.vscode-server.enable = true;
    # enable cursor vscode server
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      nodejs
    ];
  };
}