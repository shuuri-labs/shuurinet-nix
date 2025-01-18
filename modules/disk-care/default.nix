{ config, lib, pkgs, ... }:

let
  cfg = config.diskCare;
in
{
  options.diskCare = {
    enableTrim = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable fstrim service";
    };

    disksToSmartMonitor = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          device = lib.mkOption {
            type = lib.types.str;
            description = "Path to disk device";
          };
          options = lib.mkOption {
            type = lib.types.str;
            default = cfg.smartdOptionsAndSchedule;
            description = "SMART options for this disk";
          };
        };
      });
      default = [];
      description = "List of disks to monitor with smartd";
    };

    smartdOptionsAndSchedule = lib.mkOption {
      type = lib.types.str;
      default = "-a -o on -S on -s (S/../../[1-2,4-7]/05|L/../../3/05)";
      description = ''
        Default options and schedule for smartd
        Schedule format: T/MM/DD/d/HH
        Short test every day at 5am except Wednesday (d = [1-2,4-7])
        Long test every Wednesday at 5am (d = 3)
      '';
    };
  };

  config = {
    services.fstrim.enable = cfg.enableTrim;

    services.smartd = {
      enable = lib.mkIf (cfg.disksToSmartMonitor != []) true;
      devices = cfg.disksToSmartMonitor;
    };
  };
}