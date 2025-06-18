{ config, lib, pkgs, ... }:
let
  service = "paperless";

  homelab = config.homelab;
  cfg     = config.homelab.services.${service};
  storage = config.homelab.system.storage;

  common   = import ../common.nix { inherit lib config homelab service; };
  dirUtils = import ../../lib/utils/directories.nix { inherit lib pkgs; };
  idp      = import ./idp.nix { inherit config lib pkgs service; };
in
{
  options.homelab.services.${service} = common.options // {
    passwordFile = lib.mkOption {
      type = lib.types.str;
      description = "The file containing the password for the paperless web interface";
    };

    paths = {
      dataDir = lib.mkOption {
        type = lib.types.str;
        description = "The directory for paperless data";
        default = "${homelab.system.storage.directories.documents}/paperless";
      };

      consumeDir = lib.mkOption {
        type = lib.types.str;
        description = "The directory for paperless consume";
        default = "${cfg.paths.dataDir}/consume";
      };
    };
  };

  config = lib.mkMerge [
    common.config
    idp.config
    
    (lib.mkIf cfg.enable {
      homelab = {
        services.${service} = {
          port = lib.mkDefault 28981;
          fqdn.topLevel = lib.mkDefault "paper";
          idp.enable = lib.mkDefault true;
        };
      };

      environment.systemPackages = with pkgs; [
        python312Packages.inotifyrecursive
      ]; # paperless will fallback to a cpu-expensive method of dir watching if this package is not installed

      systemd.services = dirUtils.createDirectoriesService {
        serviceName = service;
        directories = cfg.paths;
        user = storage.mainStorageUserName;
        group = storage.accessGroups.documents.name;
        before = [ "paperless.service" "paperless-scheduler.service" "paperless-task-queue.service" ];
      };

      services.${service} = {
        enable = true;
        user = cfg.user;
        port = cfg.port;
        
        passwordFile = cfg.passwordFile;
        consumptionDir = cfg.paths.consumeDir;

        settings = {
          PAPERLESS_OCR_LANGUAGE = "eng+deu";
          PAPERLESS_ENABLE_HTTP_REMOTE_USER_API = true;
          PAPERLESS_CONSUMER_IGNORE_PATTERN = [
            ".DS_STORE/*"
          ];
          PAPERLESS_URL = "https://${cfg.fqdn.final}";
        };
      };

      users.users.${cfg.user}.extraGroups = [ storage.accessGroups.documents.name ];
    })
  ];
}