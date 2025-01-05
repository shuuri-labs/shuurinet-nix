{ config, lib, pkgs, ... }:

# let
#   cfg = config.mediaServer.jellyfin;
# in 
{
  # imports = [ 
  #   "${pkgs.path}/nixos/modules/services/misc/jellyfin.nix"
  #   "${pkgs.path}/nixos/modules/services/misc/jellyseer.nix"
  # ];

  # options.mediaServer.jellyfin = {
  #   enable = lib.mkOption {
  #     type = lib.types.bool;
  #     default = false;
  #     description = "Enable jellyfin media server";
  #   };
  # };

  config = {
    services.jellyfin = {
      enable = true; 
      openFirewall = true;
      user = "jellyfin";
    };

    # TODO: optional?
    services.jellyseerr = {
      enable = true; 
      openFirewall = true;
    };
  };
}