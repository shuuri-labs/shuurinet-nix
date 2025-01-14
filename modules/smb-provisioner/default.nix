{ config, pkgs, lib, ... }:

let
  cfg = config.sambaProvisioner;
in {
  options.sambaProvisioner = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable provisioning of Samba users from a list of
        user/password secrets (e.g., from agenix).
      '';
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "samba-server";
      description = ''
        Hostname to advertise.
      '';
    };

    users = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            example = "ashley";
            description = "Samba user name.";
          };
          passwordFile = lib.mkOption {
            type = lib.types.path;
            example = "/secrets/ashley.txt";
            description = "File path containing the user's password.";
          };
        };
      });
      default = [];
      description = ''
        List of submodules describing Samba users to ensure exist.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.samba = {
      enable = true; 
      openFirewall = true;
      settings.global = {
        "invalid users" = [
          "root"
        ];
        "passwd program" = "/run/wrappers/bin/passwd %u";
        security = "user";

        "server string" = cfg.hostName;
        "fruit:encoding" = "native";
        "fruit:metadata" = "stream";
        "fruit:zero_file_id" = "yes";
        "fruit:nfs_aces" = "no";
        "vfs objects" = "catia fruit streams_xattr";
        "veto files" = "/._*/.DS_Store/.Trashes/.TemporaryItems/"; # fix for MacOS "operation can’t be completed because the item is in use" error
        "delete veto files" = "yes";
      };
    };

    # advertise to windows clients
    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };

    # systemd.services.sambaUserProvisioner = {
    #   description = "Provision Samba Users";
    #   wantedBy = [ "multi-user.target" ];
    #   after = [ "samba-smbd.service" ]; # Ensure it runs after Samba starts (bit hacky)
    #   serviceConfig = {
    #     ExecStart = let
    #       userCommands = lib.concatMapStringsSep "\n" (u: ''
    #         if ! pdbedit -L -u "${u.name}" &>/dev/null; then
    #           echo "Creating Samba user: ${u.name}"
    #           smbpasswd -a "${u.name}" < "${u.passwordFile}"
    #         else
    #           echo "Samba user '${u.name}' already exists; skipping."
    #         fi
    #       '') cfg.users;
    #     in ''
    #       /usr/bin/env bash -c '
    #       set -euo pipefail
    #       ${userCommands}
    #       '
    #     '';
    #     Type = "oneshot"; # Run only once
    #   };
    # };

    systemd.services.sambaUserProvisioner = {
      description = "Provision Samba Users";
      wantedBy = [ "multi-user.target" ];
      # after = [ "samba.service" ];
      serviceConfig = let
        userCommands = lib.concatMapStringsSep "\n" (u: ''
          echo "Ensuring Samba user '${u.name}' exists..."
          if ! pdbedit -L -u "${u.name}" &>/dev/null; then
            echo "Creating Samba user: ${u.name}"
            # Read the decrypted secret at runtime:
            pass=$(cat "${u.passwordFile}")
            # Feed it twice to smbpasswd for password + confirmation:
            (echo "$pass"; echo "$pass") | smbpasswd -s -a "${u.name}"
          else
            echo "Samba user '${u.name}' already exists; skipping."
          fi
        '') cfg.users;
      in {
        ExecStart = ''
          /usr/bin/env bash -c '
          set -euo pipefail
          ${userCommands}
          '
        '';
        Type = "oneshot";
      };
    };
  };
}
