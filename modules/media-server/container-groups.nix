{ config, lib, pkgs, ... }:

{
  options.container = {
    # Input: original accessGroups from host
    hostAccessGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the group";
          };
          gid = lib.mkOption {
            type = lib.types.int;
            description = "Group ID";
          };
          governedPaths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Paths this group has access to";
          };
          guestRead = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether others can read files in governed paths";
          };
        };
      });
      default = {};
      description = "Original host access groups configuration";
    };

    # Output: stripped down version for container use
    accessGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the group";
          };
          gid = lib.mkOption {
            type = lib.types.int;
            description = "Group ID";
          };
        };
      });
      default = {};
      description = "Container access groups (stripped down version)";
      internal = true;  # This is derived from hostAccessGroups
    };
  };

  config = {
    # Convert hostAccessGroups to container.accessGroups
    container.accessGroups = lib.mapAttrs (name: group: {
      inherit (group) name gid;
    }) config.container.hostAccessGroups;
  };
}