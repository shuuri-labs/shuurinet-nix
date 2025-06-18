{ config, lib, pkgs, ... }:

with lib;

let
  homelab = config.homelab;
  cfg     = config.homelab.services.mediaServer.storage;

  directoriesUtils = import ../../lib/utils/directories.nix { inherit lib pkgs; };
in
{
  options.homelab.services.mediaServer.storage = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable media server directory service.";
    };

    group = mkOption {
      type = types.str;
      default = homelab.system.storage.accessGroups.media.name;
      description = "The group name for media directories.";
    };

    path = mkOption {
      type = types.str;
      default = homelab.system.storage.directories.media;
      description = "Base directory for media files.";
    };

    directories = {
      movies = mkOption {
        type = types.str;
        default = "${cfg.path}/movies";
        description = "Directory for movies.";
      };

      tv = mkOption {
        type = types.str;
        default = "${cfg.path}/tv";
        description = "Directory for TV shows.";
      };

      anime = mkOption {
        type = types.str;
        default = "${cfg.path}/anime";
        description = "Directory for anime.";
      };
    };

    hostMainStorageUser = mkOption {
      type = types.str;
      default = homelab.system.storage.mainStorageUserName;
      description = "The main user for the host.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services = directoriesUtils.createDirectoriesService {
      serviceName = "media-server";
      directories = cfg.directories;
      user = cfg.hostMainStorageUser;
      group = cfg.group;
    };
  };
}
