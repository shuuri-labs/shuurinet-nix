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
    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList 
      (name: path: [
        # Create directory with initial permissions - media path should already exist (created in options-host)
        "d ${path} 0775 root ${cfg.mediaGroup} -"
        # Recursively set ownership
        "R ${path} - - - - root:${cfg.mediaGroup}"
        # Recursively set directory permissions
        "z ${path}/ 0775 - - - -"
        # Recursively set file permissions (664 for files)
        "z ${path}/* 0664 - - - -"
      ]) (cfg.paths)
    );
  };
}
