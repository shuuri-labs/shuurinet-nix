{ config, lib, pkgs, ... }:

{
  options.host.storage = {
    paths = {
      documents = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/documents";
      };
    
      backups = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/backups";
      };

      downloads = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/downloads";
      };

      media = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/media";
      };

      arrMedia = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/arrMedia";
      };

      editing = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/editing";
      };
    };

    mainUserName = lib.mkOption {
      type = lib.types.str;
      default = "ashley";
    };
  };

  config = {
    systemd.tmpfiles.rules = lib.mapAttrsToList (name: path:
      "d ${path} 0755 ${config.host.storage.mainUserName} ${config.host.storage.mainUserName} -"
    ) config.host.storage.paths;
  };
}
