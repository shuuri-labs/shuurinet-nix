{ config, lib, pkgs, ... }:

with lib;

let
  setPathPermissions = path: groupName: guestRead: {
    "${path}" = {
      mode = if guestRead then "0775" else "0770";  # Group write enabled
      group = groupName;
      setgid = true;
    };
  };
in
{
  options.host = {
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
      default = "ashley";
    };
  };

  config = let
    # Combine all path permissions into a single attribute set
    allPathPermissions = lib.foldl' (acc: group:
      lib.foldl' (pathAcc: path:
        pathAcc // (setPathPermissions path group.name group.guestRead)
      ) acc group.governedPaths
    ) {} (builtins.attrValues config.host.accessGroups);
  in {
    host.accessGroups = {
      # Media 
      media = {
        name = "mediaDirAccess";
        gid = 501;
        governedPaths = [ config.host.storage.paths.media ];
        guestRead = true;
      };
      arrMedia = {
        name = "arrMediaDirAccess";
        gid = 502;
        governedPaths = [ config.host.storage.paths.arrMedia ]; 
        guestRead = true;
      };
      downloads = {
        name = "downloadsDirAccess";
        gid = 503;
        governedPaths = [ config.host.storage.paths.downloads ];
        guestRead = true;
      };

      # Documents 
      documents = {
        name = "documentsAccess";
        gid = 504;
        governedPaths = [ config.host.storage.paths.documents ];
        guestRead = false;
      };

      # Backups
      backups = {
        name = "backups";
        gid = 505;
        governedPaths = [ config.host.storage.paths.backups ];
        guestRead = false;
      };
    };

    # Create the groups
    users.groups = lib.mapAttrs (name: group: {
      inherit (group) name gid;
    }) config.host.accessGroups;

    # Add the main user to all access groups
    users.users.${config.host.mainUserName}.extraGroups = 
      lib.mkAfter (lib.mapAttrsToList (key: group: group.name) config.host.accessGroups);

    # Set path permissions only if governedPaths is not empty
    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList
      (path: conf: [
        "d ${path} ${conf.mode} root ${conf.group} - -"
        "z ${path} ${conf.mode} root ${conf.group} - -"
        "a+g ${path}"  # Ensure setgid
      ])
      allPathPermissions
    );
  };
}
