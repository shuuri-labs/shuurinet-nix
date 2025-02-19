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
      default = "-a -o on -S on -s (S/../../[1-2,4-7]/05|L/../../>2W/05)";
      description = ''
        Default options and schedule for smartd
        Schedule format: T/MM/DD/d/HH
        - Short test every day at 5 AM except Wednesdays (d = [1-2,4-7])
        - Long test on the second Wednesday of the month at 5 AM (d = >2W)
      '';
    };
  };

  config = {
    environment.systemPackages = with pkgs; [ smartmontools ];

    # automatically detects SSDs that support TRIM. Note that ZFS pools are extempt and need trim enabled on the pool level - 
    # see 'zfs/default.nix' for more info.
    services.fstrim.enable = cfg.enableTrim;

    services.smartd = {
      enable = lib.mkIf (cfg.disksToSmartMonitor != []) true;
      devices = cfg.disksToSmartMonitor;
    };
  };
}