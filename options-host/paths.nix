{ config, lib, pkgs, ... }:

{
  options.host.storage.paths = {
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
  };

  config = {
    systemd.tmpfiles.rules = lib.mapAttrsToList (name: path:
      "d ${path} 0755 root root -"
    ) config.host.storage.paths;
  };
}
