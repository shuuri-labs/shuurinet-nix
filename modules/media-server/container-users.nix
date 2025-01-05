{ config, lib, pkgs, ... }:

{
  options.container.serviceUsers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        username = lib.mkOption {
          type = lib.types.str;
          description = "The username for the account";
        };
        uid = lib.mkOption {
          type = lib.types.int;
          description = "The user's uid";
        };
        groups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Groups the user belongs to";
        };
      };
    });
    default = {};
    description = "Container service users matching host UIDs";
  };

  config = {
    # Create the groups from container.accessGroups
    users.groups = lib.mapAttrs (name: group: {
      inherit (group) name gid;
    }) config.container.accessGroups;

    # Create users with their primary and extra groups
    users.users = lib.mapAttrs (name: user: {
      name = user.username;
      uid = user.uid;
      isSystemUser = true;
      group = user.username;  # Primary group matches username
      extraGroups = user.groups;
      createHome = false;
    }) config.container.serviceUsers;

    # Create primary groups for users (same name and GID as UID)
    users.groups = lib.mkMerge [
      # Groups from container.accessGroups (already defined above)
      config.users.groups
      # Primary groups for users
      (lib.mapAttrs (name: user: {
        name = user.username;
        gid = user.uid;
      }) config.container.serviceUsers)
    ];
  };
}