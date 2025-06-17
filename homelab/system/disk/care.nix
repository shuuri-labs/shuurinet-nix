{ config, lib, pkgs, ... }:

let
  cfg = config.homelab.system.disk.care;
in
{
  options.homelab.system.disk.care = {
    trim.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable fstrim service";
    };

    smartd = { 
      disks = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            device = lib.mkOption {
              type = lib.types.str;
              description = "Path to disk device";
            };
            options = lib.mkOption {
              type = lib.types.str;
              default = cfg.smartd.options;
              description = "SMART options for this disk";
            };
          };
        });
        default = [];
        description = "List of disks to monitor with smartd";
      };

      options = lib.mkOption {
        type = lib.types.str;
        default = "-a -o on -S on -s (S/../../4/05|L/../../>2W/05)";
        description = ''
          Default options and schedule for smartd
          Schedule format: T/MM/DD/d/HH
          - Short test every **Thursday** at 5 AM (d = 4)
          - Long test on the **second Wednesday** of the month at 5 AM (d = >2W)
        '';
      };
    };
  };

  config = {
    environment.systemPackages = with pkgs; [ smartmontools ];

    # automatically detects SSDs that support TRIM. Note that ZFS pools are extempt and need trim enabled on the pool level - 
    # see 'zfs/default.nix' for more info.
    services.fstrim.enable = cfg.trim.enable;

    services.smartd = {
      enable = lib.mkIf (cfg.smartd.disks != []) true;
      devices = cfg.smartd.disks;
    };
  };
}