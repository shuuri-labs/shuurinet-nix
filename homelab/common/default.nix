{ config, pkgs, lib, stateVersion, ... }:

let
  inherit (lib) mkOption types;

  cfg = config.homelab.common;
in
{
  imports = [
    ./users-and-ssh.nix
  ];

  options.homelab.common = {
    secrets = {
      sopsKeyPath = mkOption {
        type = types.str;
        default = "";
      };
    };
  };

  config = {
    # ========= Nix system config =========

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    system.stateVersion = stateVersion;

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

    # ========= System config =========

    swapDevices = [{
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }];

    networking.firewall.enable = true; 

    time.timeZone = "Europe/Berlin";

    # locale settings
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

    #  keyboard layout
    services.xserver.xkb = {
      layout = "gb";
      variant = "";
    };
    console.keyMap = "uk";

    services.vscode-server.enable = true;
    # enable vscode server for cursor
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      nodejs
    ];

    # ========= Secrets =========

    age.identityPaths = [
      "/home/ashley/.ssh/id_ed25519"    # User SSH key
      "/etc/ssh/ssh_host_ed25519_key"   # Host SSH key, does not work with agenix
    ];
    
    environment.variables.SOPS_AGE_KEY_FILE = cfg.secrets.sopsKeyPath;
  };
}