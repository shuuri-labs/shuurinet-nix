# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    #  (fetchTarball "https://github.com/nix-community/nixos-vscode-server/tarball/master")
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.vscode-server.enable = true;

  programs.ssh.startAgent = true;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1TmZx5UfPLkQd583pbMNtlLiq2bH8vnNseYY23zDAdsQDrK5B2oLXFZVHaDeEvg592mUtCxGMXZUaSULizEntyQ82Uszel6aj33Lr3IvEH11eRBv6DjfFZ1SyYRPBqjvh/p4tSRZuqjQ/ZUH52minKCcRouDt978rhSnyIb3Q69CJjn0mBC4JIhXXxueOeKUDagRnieBGlh51VEFSw7nFH+UVep2bEKg3bNgKPBj1J9rWgnp0HB8IGwGuXH0AOyH0CKTUXkhiFbewX5ONCZwdRbvbtp3JE0W7/m4WKHuDN88+yPIAxPqrm9qZFdhiyzrY2Nc/+gO9Y/stApxEID9lcRihgKc1KYJiiLKsmB4fbkuvqXKZRoUIymId0KFCnnHPQUTNjpgy/6Hzfz0TINoS/4CR2uTaO5cUuCqYvPia/ksgeZVMKxGdKZ3CokUDRbHOMREWyqXaooHFv5BjM36UIIv5vyYxViwbfXcuVW3tmsKaUIrr2NYzmtzsN0PSZV0= ashleyamohmensah@Ashleys-MacBook-Pro.local"
    ];
  };

  users.users.ashley = {
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1TmZx5UfPLkQd583pbMNtlLiq2bH8vnNseYY23zDAdsQDrK5B2oLXFZVHaDeEvg592mUtCxGMXZUaSULizEntyQ82Uszel6aj33Lr3IvEH11eRBv6DjfFZ1SyYRPBqjvh/p4tSRZuqjQ/ZUH52minKCcRouDt978rhSnyIb3Q69CJjn0mBC4JIhXXxueOeKUDagRnieBGlh51VEFSw7nFH+UVep2bEKg3bNgKPBj1J9rWgnp0HB8IGwGuXH0AOyH0CKTUXkhiFbewX5ONCZwdRbvbtp3JE0W7/m4WKHuDN88+yPIAxPqrm9qZFdhiyzrY2Nc/+gO9Y/stApxEID9lcRihgKc1KYJiiLKsmB4fbkuvqXKZRoUIymId0KFCnnHPQUTNjpgy/6Hzfz0TINoS/4CR2uTaO5cUuCqYvPia/ksgeZVMKxGdKZ3CokUDRbHOMREWyqXaooHFv5BjM36UIIv5vyYxViwbfXcuVW3tmsKaUIrr2NYzmtzsN0PSZV0= ashleyamohmensah@Ashleys-MacBook-Pro.local"
    ];
  };

  networking.hostName = "castform"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ashley = {
    isNormalUser = true;
    description = "Ashley";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    git
    htop
    age
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
   services.openssh.enable = true;

  age.identityPaths = [
    # "/home/ashley/.ssh/id_ed25519"
    "/home/${config.common.mainUsername}/.ssh/id_ed25519"     # User SSH key
    # "/etc/ssh/ssh_host_ed25519_key"          # Host SSH key
  ];

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
