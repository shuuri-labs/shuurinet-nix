{ config, pkgs, ... }:

{
  home.username = "ashley";
  home.homeDirectory = "/home/ashley";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    shellAliases = {
      nxrb = "sudo nixos-rebuild switch --flake /home/ashley/shuurinet-nix" ; # TODO - change/symlink default rebuild path so I don't have to specify
      cdnx = "cd /home/ashley/shuurinet-nix";
      lservices = "systemctl list-units --type=service --state=running";
      laservices = "systemctl list-units --type=service";
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
  # home.enableNixpkgsReleaseCheck = false;

  home.packages = with pkgs; [
    netbird
    home-manager
  ];
}