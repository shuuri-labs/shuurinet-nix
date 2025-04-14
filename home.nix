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
      nxrb = "sudo nixos-rebuild switch --flake ~/shuurinet-nix"; # must create symlink if not using default config dir
      nfuu = "nix flake update --update-input nixpkgs-unstable";
      nfus = "nix flake update";
      cdnx = "cd ~/shuurinet-nix";
      lservices = "systemctl list-units --type=service --state=running";
      laservices = "systemctl list-units --type=service";
      igtop = "nix-shell -p intel-gpu-tools --run \"sudo intel_gpu_top\"";
      container-login = "sudo nixos-container root-login";
      dhealth = ''
        #!/bin/bash

        # List all disk devices
        for disk in $(lsblk -d -n -o NAME,TYPE | awk '$2 == "disk" {print $1}'); do
          echo "SMART status for /dev/$disk:"
          sudo smartctl -H /dev/$disk
          echo
        done
      '';
      itp = "sudo iotop -o -P"; # check which processes are using the most disk I/O (all disks)
      grbg = "sudo nix-collect-garbage -d";
      lsgen = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      nxrlbk = "sudo nixos-rebuild switch --flake ~/shuurinet-nix --rollback";
    };

    sessionVariables = {
      SOPS_AGE_KEY_FILE = "/run/agenix/sops-key";
    };
  };

  programs.git = {
    enable = true;
    userName = "Ashley Mensah";
    userEmail = "mail@shuurilabs.com";
  };
}