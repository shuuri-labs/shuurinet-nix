{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mediaServer.storage;
in
{
  options.mediaServer.storage = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable media server directory service.";
    };

    group = mkOption {
      type = types.str;
      description = "The group name for media directories.";
    };

    path = mkOption {
      type = types.str;
      default = "/mnt/media";
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
      description = "The main user for the host.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.media-server-permissions = {
      description = "Set media server directory permissions";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-users-groups.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "set-media-permissions" ''
          # Create directories if they don't exist
          ${builtins.concatStringsSep "\n" (lib.mapAttrsToList 
            (name: path: ''
              ${pkgs.coreutils}/bin/mkdir -p ${path}
              ${pkgs.coreutils}/bin/chown -R ${cfg.hostMainStorageUser}:${cfg.group} ${path}
              ${pkgs.coreutils}/bin/chmod -R u=rwX,g=rwX,o=rX ${path}
            '')
            cfg.directories
          )}
        '';
      };
    };
  };
}
