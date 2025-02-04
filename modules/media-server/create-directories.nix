{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mediaServer;
in
{
  options.mediaServer = {
    mediaGroup = mkOption {
      type = types.str;
      description = "The group name for media directories.";
    };

    mediaDir = mkOption {
      type = types.str;
      default = "/mnt/media";
      description = "Base directory for media files.";
    };

    paths = {
      movies = mkOption {
        type = types.str;
        default = "${cfg.mediaDir}/movies";
        description = "Directory for movies.";
      };

      tv = mkOption {
        type = types.str;
        default = "${cfg.mediaDir}/tv";
        description = "Directory for TV shows.";
      };

      anime = mkOption {
        type = types.str;
        default = "${cfg.mediaDir}/anime";
        description = "Directory for anime.";
      };
    };
  };

  config = {
    systemd.tmpfiles.rules = lib.mapAttrsToList
      (name: path: 
        # Create directory if it doesn't exist with group write enabled
        "d ${path} 0775 root ${cfg.mediaGroup} -"
      ) (cfg.paths);
  };
}
