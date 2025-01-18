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
    };
  };

  programs.git = {
    enable = true;
    userName = "Ashley Mensah";
    userEmail = "ashleyamo982@gmail.com"; # TODO: encrypt
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