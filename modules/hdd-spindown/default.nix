{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf;
  cfg = config.hddSpindown;
in
{
  options.hddSpindown = {
    disks = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        List of disks IDs to spin down
        Print disk ids with: ls -l /dev/disk/by-id/
      '';
    };

    spinDownTime = mkOption {
      type = lib.types.str;
      default = "242"; # 1 hour
      description = ''
        Set the standby (spindown) timeout for the drive. 
        The timeout specifies how long to wait in idle (with no disk activity) before turning off the motor to save power.
        The value of 0 disables spindown, the values from 1 to 240 specify multiples of 5 seconds and values from 241 to 251 specify multiples of 30 minutes. 
        https://wiki.archlinux.org/title/Hdparm
      '';
    };
  };
  
  config = mkIf (builtins.length cfg.disks > 0) {
    environment.systemPackages = [
      pkgs.hdparm
    ];

    systemd.services.hdparmSpindown = {
      description = "Set hdparm spindown at boot";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        # Create a script that runs hdparm for each disk
        ExecStart = let
          script = pkgs.writeShellScript "hdparm-spindown" ''
            ${lib.concatMapStringsSep "\n" (disk: ''
              ${pkgs.hdparm}/bin/hdparm -B 127 -S ${cfg.spinDownTime} /dev/disk/by-id/${disk}
            '') cfg.disks}
          '';
        in "${script}";
      };
    };
  };
}