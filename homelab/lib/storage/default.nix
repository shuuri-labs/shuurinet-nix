{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.homelab.storage;
in
{
  options.homelab.storage = {
    paths = {
      bulkStorage = lib.mkOption {
        type = lib.types.str;
        default = "/home/ashley/";
      };

      fastStorage = lib.mkOption {
        type = lib.types.str;
        default = cfg.paths.bulkStorage;
      };

      editingStorage = lib.mkOption {
        type = lib.types.str;
        default = cfg.paths.bulkStorage;
      };
    };

    directories = {
      documents = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.paths.fastStorage}/documents";
      };
    
      backups = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.paths.fastStorage}/backups";
      };

      downloads = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.paths.fastStorage}/downloads";
      };

      media = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.paths.bulkStorage}/media";
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
          governedDirectories = mkOption {
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

    mainStorageUserName = mkOption {
      type = types.str;
      description = "The host's main user name";
      default = "ashley";
    };
  };

  config = {
     homelab.storage.accessGroups = {
      media = {
        name = "mediaDirAccess";
        gid = 501;
        governedDirectories = [ cfg.directories.media ];
        guestRead = true;
      };

      downloads = {
        name = "downloadsDirAccess";
        gid = 503;
        governedDirectories = [ cfg.directories.downloads ];
        guestRead = false;
      };

      documents = {
        name = "documentsAccess";
        gid = 504;
        governedDirectories = [ cfg.directories.documents ];
        guestRead = false;
      };

      backups = {
        name = "backups";
        gid = 505;
        governedDirectories = [ cfg.directories.backups ];
        guestRead = false;
      };
    };

    # Create access groups
    users.groups = lib.mapAttrs (name: group: {
      inherit (group) name gid;
    }) cfg.accessGroups;

    # Add the main user to all access groups
    users.users.${cfg.mainStorageUserName}.extraGroups = 
       (lib.mapAttrsToList (key: group: group.name) cfg.accessGroups);

    # Create directories if they don't exist and set group permissions
    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList 
      (name: group: map 
        (directory: "d ${directory} 0${if group.guestRead then "775" else "770"} ${cfg.mainStorageUserName} ${group.name} -")
        group.governedDirectories
      )
      cfg.accessGroups
    );
  };
}
