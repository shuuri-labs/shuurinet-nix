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

    hostIp = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0/0";
      description = "IP address to advertise.";
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
          createHostUser = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to create a corresponding system user.";
          };
          extraGroups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Extra groups to add to the new user.";
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
        # Bind only to IPv4 - NOTE: not advertising on IPv6 means share won't show up on 'Network' tab on Mac OS
        # need to connect to server's IPv4 manually
        # "bind interfaces only" = "yes";
        # "interfaces" = [ cfg.hostIp ]; 

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

    # Create the users if specified that they don't already exist - samba needs a linux user to exist to create the samba equivalent
    users.users = lib.listToAttrs (map (u: {
      name = u.name;
      value = {
        isNormalUser = true;
        description = "${u.name} samba user";
        shell = pkgs.shadow;
        extraGroups = u.extraGroups;
      };
    }) (lib.filter (u: u.createHostUser) cfg.users));  

    # SAMBA User Provisioning - if user already exists, set password for both 'password' and 'confirmation' prompts
    systemd.services.sambaUserProvisioner = {
      description = "Provision Samba Users";
      wantedBy = [ "multi-user.target" ];
      enable = true;
      after = [ "samba-smbd.service" ];
      serviceConfig = let
        userCommands = lib.concatMapStringsSep "\n" (u: ''
          echo "Setting password for Samba user '${u.name}'..."
          pass=$(cat "${u.passwordFile}")
          (echo "$pass"; echo "$pass") | smbpasswd -s -a "${u.name}"
        '') cfg.users;
      in {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "provision-samba-users" ''
          export PATH=${lib.makeBinPath [ pkgs.samba ]}:$PATH
          set -euo pipefail
          ${userCommands}
        '';
      };
    };
  };
}
