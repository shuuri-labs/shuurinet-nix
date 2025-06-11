{ config, lib, pkgs, ... }:

imports = [
  ./prowlarr.nix
  ./radarr.nix
  ./sonarr.nix
  ./bazarr.nix
];

options.homelab.services.arr.enableStack = lib.mkEnableOption "Enable the arr stack";

config = lib.mkIf config.homelab.services.arr.enableStack {
  homelab.services.prowlarr.enable = true;
  homelab.services.radarr.enable = true;
  homelab.services.sonarr.enable = true;
  homelab.services.bazarr.enable = true;
};

