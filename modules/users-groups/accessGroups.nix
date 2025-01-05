{ config, lib, pkgs, ... }:

with lib;

let
  # Helper function to set permissions for a path
  setPathPermissions = path: groupName: guestRead: {
    "${path}" = {
      mode = if guestRead then "0755" else "0750";
      group = groupName;
      # Ensure group ownership and setgid bit
      inherit groupName;
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
  };

  config = let
    # Create a single attribute set of all path permissions
    allPathPermissions = lib.foldl
      (acc: group: acc // (lib.foldl
        (pathAcc: path: pathAcc // (setPathPermissions path group.name group.guestRead))
        {}
        group.governedPaths
      ))
      {}
      (builtins.attrValues config.host.accessGroups);
  in {
    host.accessGroups = {
      # Media 
      media = {
        name = "mediaDirAccess";
        gid = 501;
        governedPaths = [ "${config.host.storage.paths.media}" ];
        guestRead = true;
      };
      arrMedia = {
        name = "arrMediaDirAccess";
        gid = 502;
        governedPaths = [ "${config.host.storage.paths.arrMedia}" ];
        guestRead = true;
      };
      downloads = {
        name = "downloadsDirAccess";
        gid = 503;
        governedPaths = [ "${config.host.storage.paths.downloads}" ];
        guestRead = true;
      };

      # Documents 
      documents = {
        name = "documentsAccess";
        gid = 504;
        governedPaths = [ "${config.host.storage.paths.documents}" ];
        guestRead = false;
      };

      # Backups
      backups = {
        name = "backups";
        gid = 505;
        governedPaths = [ "${config.host.storage.paths.backups}" ];
        guestRead = false;
      };
    };

    # Create the groups
    users.groups = lib.mapAttrs (name: group: {
      inherit (group) name gid;
    }) config.host.accessGroups;

    # Set path permissions only if governedPaths is not empty
    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList
      (path: conf: [
        "d ${path} ${conf.mode} root ${conf.group} - -"
        "z ${path} ${conf.mode} root ${conf.group} - -"
      ])
      allPathPermissions
    );
  };
}