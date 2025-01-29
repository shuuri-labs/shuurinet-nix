{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf types;
  cfg = config.host.zfs; 

  # find the latest kernel package that supports ZFS (since it's not always supported by newest kernel)
  zfsCompatibleKernelPackages = lib.filterAttrs (
    name: kernelPackages:
    (builtins.match "linux_[0-9]+_[0-9]+" name) != null
    && (builtins.tryEval kernelPackages).success
    && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
  ) pkgs.linuxKernel.packages;

  latestKernelPackage = lib.last (
    lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
      builtins.attrValues zfsCompatibleKernelPackages
    )
  );

  # script to set autotrim for SSD pools where config.host.zfs.pools.<pool>.autotrim is true
  zfsAutotrimScript = pkgs.writeScript "zfs-autotrim.sh" ''
    #!/bin/sh
    ${lib.concatMapStringsSep "\n" (pool: ''
      if [ "${if pool.autotrim then "true" else "false"}" = "true" ]; then
        ${pkgs.zfs}/bin/zpool set autotrim=on ${pool.name}
      fi
    '') (builtins.attrValues cfg.pools)}
  '';
in
{
  options.host.zfs = {
    pools = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the ZFS pool";
          };
          autotrim = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Enable autotrim for this pool. For supported SSDs only.
            '';
          };
        };
      });
      default = {};
      description = "ZFS pools configuration";
      example = {
        rpool = {
          name = "rpool";
          autotrim = true;
        };
        backup = {
          name = "backup";
          autotrim = false;
        };
      };
    };

    network.hostId = mkOption {
      type = types.str;
      default = null; 
      description = ''
        'config.networking.hostId' option required for ZFS
        generate with: head -c4 /dev/urandom | od -A none -t x4
      '';
    };
  };
  
  config = mkIf (builtins.length (builtins.attrNames cfg.pools) > 0) {
    networking.hostId = cfg.network.hostId; 

    boot.kernelPackages = latestKernelPackage;

    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.forceImportAll = true; # force importing of pools last used with another machine/hostId

    boot.zfs.extraPools = map (pool: pool.name) (builtins.attrValues cfg.pools);

    services.zfs.autoScrub = {
      enable = true;
      interval = "Wed *-*-01..07,15..21 05:30:00"; # biweekly (first wednesday between 1st and 7th, and 15th and 21st)
    };

    # Systemd service to set autotrim
    systemd.services.zfs-autotrim = {
      description = "Set ZFS autotrim for specified pools";
      after = [ "zfs-import.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${zfsAutotrimScript}";
        Type = "oneshot";
      };
    };
  };
}