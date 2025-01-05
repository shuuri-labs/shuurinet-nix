{ config, lib, ... }:

{
  options.host.storage.paths = {
    media = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media";
    };

    downloads = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/downloads";
    };

    arrMedia = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/arrMedia";
    };

    documents = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/documents";
    };
    
    backups = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/backups";
    };
  };
}
