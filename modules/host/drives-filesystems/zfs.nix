{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf;
  cfg = config.host.zfs; 
in
{
  options.host.zfs = {
    mountedPools = mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = mkOption {
            type = lib.types.str;
            description = "Name of the ZFS pool";
          };
          path = mkOption {
            type = lib.types.str;
            description = "Mount path for the ZFS pool";
          };
          driveIds = mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "List of drive IDs associated with the pool";
          };
        };
      });
      default = {};
      description = "Mounted pools";
    };
  };

  config = mkIf (builtins.length (builtins.attrNames cfg.mountedPools) > 0) {
    boot.supportedFilesystems = [ "zfs" ];

    environment.systemPackages = [ pkgs.zfs ];

    # Configure ZFS services
    systemd.services.import-zfs-pools = {
      description = "Import ZFS Pools";
      wants = [ "zfs-import.target" ];
      after = [ "zfs-import.target" ];
      before = [ "local-fs.target" ];
      unitConfig.ConditionPathExists = "/etc/zfs/zpool.cache";

      serviceConfig = {
        ExecStartPre = "${pkgs.zfs}/bin/zpool import -aNf";
        ExecStart = "${pkgs.zfs}/bin/zpool import -aNf";
        RemainAfterExit = true;
      };
    };

    # Use the zfs.pool names to generate custom import logic if specified
    systemd.services.custom-zfs-import = {
      description = "Custom Import ZFS Pools";
      wants = [ "import-zfs-pools.service" ];
      after = [ "import-zfs-pools.service" ];
      before = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.concatMapStrings (pool: ''
          ${pkgs.zfs}/bin/zpool import -f ${pool.name}
          ${pkgs.zfs}/bin/zfs set mountpoint=${pool.path} ${pool.name}
        '') (builtins.attrValues cfg.mountedPools);
        RemainAfterExit = true;
      };
    };

    # Activate ZFS and mount pools
    systemd.services.zfs-mount = {
      description = "Mount ZFS Filesystems";
      wants = [ "custom-zfs-import.service" ];
      after = [ "custom-zfs-import.service" ];
      before = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.zfs}/bin/zfs mount -a";
        RemainAfterExit = true;
      };
    };

    # Enable zfs-import.target at boot
    systemd.targets."zfs-import" = {
      description = "ZFS Import Target";
      wantedBy = [ "multi-user.target" ];
    };
  };
}