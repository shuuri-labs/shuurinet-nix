{ lib, pkgs }:

{ serviceName, src, dest, owner ? "root", group ? "root", mode ? "0644", wantedBy ? [ "multi-user.target" ], after ? [ "local-fs.target" ], description ? "Copy config file" }:
let
  # The hash of the source file, so the ExecStart changes if the file changes
  srcHash = builtins.hashFile "sha256" src;
in
{
  "copy-${serviceName}-config" = {
    inherit description wantedBy after;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "copy-${serviceName}-config" ''
        set -euo pipefail
        install -Dm${mode} ${src} ${dest}
        chown ${owner}:${group} ${dest}
      '';
      # This ensures the service is re-executed if the source changes
      Environment = [ "SRC_HASH=${srcHash}" ];
    };
  };
}