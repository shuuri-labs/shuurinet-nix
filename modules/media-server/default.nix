{ config, lib, pkgs, ... }:

let
  cfg = config.mediaServer;
  inherit (lib) types;
in
{
  imports = [
    ./vpn-confinement.nix
    ./create-directories.nix
    ./services.nix
  ];

  options.mediaServer = {
    enable = lib.mkOption {
      type = types.bool; 
      default = false; 
      description = ""; 
    };
  };

  config = {
    mediaServer.vpnConfinement.enable = cfg.enable;
    mediaServer.services.enable = cfg.enable;
    mediaServer.storage.enable = cfg.enable;
  };
}