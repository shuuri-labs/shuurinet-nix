{ config, lib, pkgs, ... }:

let
  cfg = config.virtualization.bareMetal; 
in
{
  options.virtualization.bareMetal = {
    enable = lib.mkEnableOption "bare metal virtualization";
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernelParams = [ "iommu=on" "iommu=pt" ];
      initrd.kernelModules = [ "vfio_iommu_type1" "vfio_pci" ];
    };

    virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
  };
}