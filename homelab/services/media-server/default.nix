{ config, lib, pkgs, ... }:

let
  cfg = config.homelab.services.mediaServer;
in
{
  imports = [
    ./storage.nix
    ../transmission
    ../arr
    ../jellyfin
  ];

  options.homelab.services.mediaServer = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable media server service.";
    };
  };

  config = lib.mkIf cfg.enable {
    homelab = {
      services = { 
        mediaServer.storage.enable = true; 
        
        transmission.enable = true;
        arr.enableStack = true;
        jellyfin.enable = true;
      };
    };
  };
}