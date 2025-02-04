{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.host.storage;
in
{
  options.host.storage = {
    paths = {
      documents = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/documents";
      };
    
      backups = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/backups";
      };

      downloads = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/downloads";
      };

      media = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/media";
      };
    };

    accessGroups = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the group";
          };
          gid = mkOption {
            type = types.int;
            description = "Group ID";
          };
          governedPaths = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Paths this group has access to";
          };
          guestRead = mkOption {
            type = types.bool;
            default = false;
            description = "Whether others can read files in governed paths";
          };
        };
      });
      default = {};
    };

    mainUserName = mkOption {
      type = types.str;
      description = "The host's main user name";
      default = "ashley";
    };
  };

  config = {
     host.storage.accessGroups = {
      media = {
        name = "mediaDirAccess";
        gid = 501;
        governedPaths = [ cfg.paths.media ];
        guestRead = true;
      };

      downloads = {
        name = "downloadsDirAccess";
        gid = 503;
        governedPaths = [ cfg.paths.downloads ];
        guestRead = false;
      };

      documents = {
        name = "documentsAccess";
        gid = 504;
        governedPaths = [ cfg.paths.documents ];
        guestRead = false;
      };

      backups = {
        name = "backups";
        gid = 505;
        governedPaths = [ cfg.paths.backups ];
        guestRead = false;
      };
    };

    # Create access groups
    users.groups = lib.mapAttrs (name: group: {
      inherit (group) name gid;
    }) cfg.accessGroups;

    # Add the main user to all access groups
    users.users.${cfg.mainUserName}.extraGroups = 
       (lib.mapAttrsToList (key: group: group.name) cfg.accessGroups);

    # Create directories if they don't exist and set group permissions
    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList 
      (name: group: map 
        (path: "d ${path} 0${if group.guestRead then "775" else "770"} root ${group.name} -")
        group.governedPaths
      )
      cfg.accessGroups
    );
  };
}
