{ config, pkgs, stateVersion, ... }:

{
  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
  # set version to system stateVersion defined in flakeHelper.nix
  home.stateVersion = stateVersion;

  home.username = "ashley";
  home.homeDirectory = "/home/ashley";

  home.sessionVariables = {
    EDITOR = "nano";
  };

  home.packages = with pkgs; [
    home-manager
  ];

  programs.bash = {
    enable = true;
    shellAliases = {
      nxrb = "sudo nixos-rebuild switch --flake ~/shuurinet-nix";
      nxrbi = "sudo nixos-rebuild switch --flake ~/shuurinet-nix --impure";
      lsgen = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      nxrlbk = "sudo nixos-rebuild switch --flake ~/shuurinet-nix --rollback";
      grbg = "sudo nix-collect-garbage -d";

      nfuu = "nix flake update --update-input nixpkgs-unstable";
      nfuv = "nix flake update --update-input nixpkgs-virtualisation";
      nfuo = "nix flake update --update-input nixpkgs-openwrt";
      nfus = "nix flake update";

      cdnx = "cd ~/shuurinet-nix";
      lservices = "systemctl list-units --type=service --state=running";
      laservices = "systemctl list-units --type=service";

      igtop = "nix-shell -p intel-gpu-tools --run \"sudo intel_gpu_top\"";
      itp = "sudo iotop -o -P"; # check which processes are using the most disk I/O (all disks)
      dhealth = ''
        #!/bin/bash

        # List all disk devices
        for disk in $(lsblk -d -n -o NAME,TYPE | awk '$2 == "disk" {print $1}'); do
          echo "SMART status for /dev/$disk:"
          sudo smartctl --all /dev/$disk
          echo
        done
      '';

      container-login = "sudo nixos-container root-login";
    };

    sessionVariables = {
      SOPS_AGE_KEY_FILE = "/run/agenix/sops-key.agekey";
    };
  };

  programs.git = {
    enable = true;
    userName = "Ashley Mensah";
    userEmail = "mail@shuurilabs.com";
  };
}