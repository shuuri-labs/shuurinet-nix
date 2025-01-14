{ config, pkgs, lib, ... }:

let
  cfg = config.services.sambaProvisioner;
in {

  #####
  # 1) Define the module options
  #####
  options.services.sambaUserProvisioner = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable provisioning of Samba users from a list of
        user/password secrets (e.g., from agenix).
      '';
    };

    users = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf {
        name = lib.types.str;
        passwordFile = lib.types.path;
      });
      default = [];
      description = ''
        List of Samba users to ensure exist. Each item must have:
          name          = the username
          passwordFile  = file path containing the user password
      '';
    };
  };

  # advertise to windows clients
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  config = lib.mkIf cfg.enable {
    services.samba = {
      enable = true; 
      openFirewall = true;
      securityType = "user";
    };

    # create Samba users from 'users' option
    system.activationScripts.sambaUserProvisioner = {
      text = let
        userCommands = lib.concatMapStringsSep "\n" (u: ''
          # Check if the user already exists in Samba
          if ! pdbedit -L -u "${u.name}" &>/dev/null; then
            echo "Creating Samba user: ${u.name}"
            smbpasswd -a "${u.name}" < "${u.passwordFile}"
          else
            echo "Samba user '${u.name}' already exists; skipping."
          fi
        '') cfg.users;
      in ''
        #!/usr/bin/env bash
        set -euo pipefail

        ${userCommands}
      '';
    };
  };
}
