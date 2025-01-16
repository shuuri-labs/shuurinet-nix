{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf types;
  cfg = config.host.zfs; 

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
in
{
  options.host.zfs = {
    pools = mkOption {
      type = types.listOf types.str; 
      default = [];
      description = "ZFS pools to import";
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
  
  config = mkIf (builtins.length cfg.pools > 0) { # TODO: add assertion for hostId
    networking.hostId = cfg.network.hostId; 

    boot.kernelPackages = latestKernelPackage; # use function in 'let' block to find and install/use latest kernel with ZFS support

    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.forceImportAll = true; # force importing of pools last used with another machine/hostId

    boot.zfs.extraPools = cfg.pools; # use extraPools instead of pools, pools wasn't automounting @ boot for some reason
    services.zfs.autoScrub.enable = true;
  };
}