 { lib, config, ... }:
let
  cfg = config.homelab;
in
{ 
  options.homelab = {
    storage = {
      bulk = lib.mkOption {
        type = lib.types.str;
      };

      fast = lib.mkOption {
        type = lib.types.str;
        default = cfg.paths.bulkStorage;
      };

      editing = lib.mkOption {
        type = lib.types.str;
        default = cfg.paths.bulkStorage;
      };
    };

    directories = {
      documents = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.storage.fast}/documents";
      };

      backups = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.storage.fast}/backups";
      };

      downloads = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.storage.fast}/downloads";
      };
      
      media = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.storage.bulk}/media";
      };
    };
  };
}