{ config, pkgs, ... }:

{
  home.username = "ashley";
  home.homeDirectory = "/home/ashley";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;

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
  };

  programs.git = {
    enable = true;
    userName = "Ashley Mensah";
    userEmail = "mail@shuurilabs.com";
  };

  home.sessionVariables = {
    EDITOR = "nano";
  };

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    netbird
    home-manager
  ];
}