{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf;
  cfg = config.host.hddSpindown;
in
{
  options.host.hddSpindown = {
    disksToSpindown = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of disks IDs to spin down";
    };

    spinDownTime = mkOption {
      type = lib.types.int;
      default = 242; # 1 hour
      description = "Disks spin down after being inactive for <x> (hdparm time format)";
    };
  };
  
  config = mkIf (builtins.length cfg.disksToSpindown > 0) {
    environment.systemPackages = [
      pkgs.hdparm
    ];

    systemd.services.hdparmSpindown = {
      description = "Set hdparm spindown at boot";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.concatMapStringsSep ";" (disk: 
          "${pkgs.hdparm}/sbin/hdparm -B 127 -S ${cfg.spinDownTime} /dev/disk/by-id/${disk}"
        ) cfg.disksToSpindown;
      };
    };
  };
}