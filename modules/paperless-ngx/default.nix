{ config, lib, pkgs, ... }:

let
  cfg = config.paperless-ngx;
in
{
  options.paperless-ngx = {
    enable = lib.mkEnableOption "paperless-ngx";

    passwordFile = lib.mkOption {
      type = lib.types.str;
      description = "The file containing the password for the paperless-ngx web interface";
    };

    documentsDir = lib.mkOption {
      type = lib.types.str;
      description = "The host's documents directory within which to place the paperless directory";
    };

    hostMainStorageUser = lib.mkOption {
      type = lib.types.str;
      description = "The main user for the host.";
    };
    
    documentsAccessGroup = lib.mkOption {
      type = lib.types.str;
      description = "The host group with access to the documents directory";
    };

    paths = {
      paperlessDir = lib.mkOption {
        type = lib.types.str;
        description = "The directory for paperless";
        default = "${cfg.documentsDir}/paperless";
      };
      paperlessMediaDir = lib.mkOption {
        type = lib.types.str;
        description = "The directory for paperless media";
        default = "${cfg.paths.paperlessDir}/media";
      };
      paperlessConsumeDir = lib. mkOption {
        type = lib.types.str;
        description = "The directory for paperless consume";
        default = "${cfg.paths.paperlessDir}/consume";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # create a service rather than using tmpfiles, because the paperless service also uses tmpfiles to own the dirs and causes conflicts
        systemd.services.create-paperless-dirs = {
      description = "Create and own Paperless directories";
      wantedBy = [ "multi-user.target" ];
      before = [ "paperless-scheduler.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "create-paperless-dirs" ''
          ${builtins.concatStringsSep "\n" (lib.mapAttrsToList 
            (name: path: ''
              ${pkgs.coreutils}/bin/mkdir -p ${path}
              ${pkgs.coreutils}/bin/chown ${cfg.hostMainStorageUser}:${cfg.documentsAccessGroup} ${path}
              ${pkgs.coreutils}/bin/chmod u=rwX,g=rwX,o=rX ${path}
            '')
            cfg.paths
          )}
        '';
      };
    };

    environment.systemPackages = with pkgs; [
      python312Packages.inotifyrecursive
    ]; # paperless will fallback to a cpu expensive method of dir watching if this package is not installed

    services.paperless = {
      enable = true;
      address = "0.0.0.0";
      passwordFile = cfg.passwordFile;
      mediaDir = cfg.paths.paperlessMediaDir;
      consumptionDir = cfg.paths.paperlessConsumeDir;

      settings = {
        PAPERLESS_OCR_LANGUAGE = "eng+deu";
        PAPERLESS_ENABLE_HTTP_REMOTE_USER_API = true;
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
        ];
      };
    };

    users.users."paperless".extraGroups = [ cfg.documentsAccessGroup ];
    networking.firewall.allowedTCPPorts = [ 28981 ];
  };
}