{ config, lib, pkgs, ... }:

let
  cfg = config.paperless-ngx;
  
  paperlessDir = "${cfg.documentsDir}/paperless";
  paperlessMediaDir = "${paperlessDir}/media";
  paperlessConsumeDir = "${paperlessDir}/consume";
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

    documentsAccessGroup = lib.mkOption {
      type = lib.types.str;
      description = "The group that has access to the documents directory";
    };
  };

  config = lib.mkIf cfg.enable {
    # create a service rather than using tmpfiles, because the paperless service also uses tmpfiles to own the dirs and causes conflicts
    systemd.services.create-paperless-dirs = {
      description = "Create Paperless directories";
      wantedBy = [ "multi-user.target" ];
      before = [ "paperless-scheduler.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "${pkgs.coreutils}/bin/mkdir -p ${paperlessDir}"
          "${pkgs.coreutils}/bin/mkdir -p ${paperlessMediaDir}"
          "${pkgs.coreutils}/bin/mkdir -p ${paperlessConsumeDir}"
          "${pkgs.coreutils}/bin/chown -R root:${cfg.documentsAccessGroup} ${paperlessDir}"
        ];
      };
    };

    services.paperless = {
      enable = true;
      address = "0.0.0.0";
      passwordFile = cfg.passwordFile;
      mediaDir = paperlessMediaDir;
      consumptionDir = paperlessConsumeDir;
    };

    users.users."paperless".extraGroups = [ cfg.documentsAccessGroup ];
    networking.firewall.allowedTCPPorts = [ 28981 ];
  };
}