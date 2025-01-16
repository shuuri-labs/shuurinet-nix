{ config, lib, pkgs, ... }:

with lib;

let
  # Instead of returning { "${path}" = { mode = ... } }
  # we return a simple attr set with { path = ..., mode = ..., group = ... }
  setPathPermissions = path: groupName: guestRead: {
    path = path;
    mode = if guestRead then "0775" else "0770";  # Group write enabled
    group = groupName;
    setgid = true;  # We'll store this as info, but systemd.tmpfiles won't use it directly
  };
in
{
  options.mediaServer.paths = {
    mediaGroup = mkOption {
      type = types.str;
      description = "The group name for media directories.";
    };

    media = mkOption {
      type = types.str;
      default = "/mnt/media";
      description = "Base directory for media files.";
    };

    movies = mkOption {
      type = types.str;
      default = "${config.mediaServer.paths.media}/movies";
      description = "Directory for movies.";
    };

    tv = mkOption {
      type = types.str;
      default = "${config.mediaServer.paths.media}/tv";
      description = "Directory for TV shows.";
    };

    anime = mkOption {
      type = types.str;
      default = "${config.mediaServer.paths.media}/anime";
      description = "Directory for anime.";
    };

    arrMedia = mkOption {
      type = types.str;
      default = "/mnt/arrMedia";
      description = "Base directory for media managed by Arr apps.";
    };

    arrMovies = mkOption {
      type = types.str;
      default = "${config.mediaServer.paths.arrMedia}/movies";
      description = "Directory for movies managed by Arr apps.";
    };

    arrTv = mkOption {
      type = types.str;
      default = "${config.mediaServer.paths.arrMedia}/tv";
      description = "Directory for TV shows managed by Arr apps.";
    };

    arrAnime = mkOption {
      type = types.str;
      default = "${config.mediaServer.paths.arrMedia}/anime";
      description = "Directory for anime managed by Arr apps.";
    };
  };

  # config = let
  #   # Each key in this set is just a label (e.g., "media", "movies"),
  #   # and the value is an attrset containing { path, mode, group, setgid }.
  #   allPathPermissions = {
  #     media    = setPathPermissions config.mediaServer.paths.media    config.mediaServer.paths.mediaGroup true;
  #     movies   = setPathPermissions config.mediaServer.paths.movies   config.mediaServer.paths.mediaGroup true;
  #     tv       = setPathPermissions config.mediaServer.paths.tv       config.mediaServer.paths.mediaGroup true;
  #     anime    = setPathPermissions config.mediaServer.paths.anime    config.mediaServer.paths.mediaGroup true;
  #     arrMedia = setPathPermissions config.mediaServer.paths.arrMedia config.mediaServer.paths.mediaGroup true;
  #     arrMovies= setPathPermissions config.mediaServer.paths.arrMovies config.mediaServer.paths.mediaGroup true;
  #     arrTv    = setPathPermissions config.mediaServer.paths.arrTv    config.mediaServer.paths.mediaGroup true;
  #     arrAnime = setPathPermissions config.mediaServer.paths.arrAnime config.mediaServer.paths.mediaGroup true;
  #   };
  # in {
  #   # Generate tmpfiles rules from allPathPermissions
  #   systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList
  #     (name: conf: [
  #       # 'd' = create directory if it doesn't exist; 'z' = apply SELinux label
  #       "d ${conf.path} ${conf.mode} root ${conf.group} - -"
  #       "z ${conf.path} ${conf.mode} root ${conf.group} - -"
  #     ])
  #     allPathPermissions
  #   );
  # };
}
