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

  config = lib.mkIf cfg.enable {
    mediaServer.vpnConfinement.enable = true;
    mediaServer.services.enable = true;
  };
}