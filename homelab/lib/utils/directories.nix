{ lib, pkgs }:

rec {
  # Pure function to create directory creation shell script
  createDirectoriesScript = {
    directories,
    user ? "ashley",
    group ? "ashley", 
    permissions ? "775"
  }: 
  let
    # Convert directories to list if it's an attrset
    dirList = if lib.isAttrs directories 
             then lib.mapAttrsToList (name: path: path) directories
             else directories;
    
    # Create shell commands for each directory
    createDirCommands = map (dir: ''
      ${pkgs.coreutils}/bin/mkdir -p "${dir}"
      ${pkgs.coreutils}/bin/chown -R ${user}:${group} "${dir}"
      ${pkgs.coreutils}/bin/chmod -R ${permissions} "${dir}"
    '') dirList;
  in
  pkgs.writeShellScript "create-directories" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n" createDirCommands}
  '';

  # Helper function to create a systemd service for directory creation
  createDirectoriesService = {
    serviceName,
    directories,
    user ? "ashley",
    group ? "ashley",
    permissions ? "775",
    description ? "Create and configure directories",
    wantedBy ? [ "multi-user.target" ],
    before ? []
  }:
  let
    script = createDirectoriesScript {
      inherit directories user group permissions;
    };
  in
  {
    "create-${serviceName}-dirs" = {
      inherit description wantedBy before;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = script;
      };
    };
  };
}