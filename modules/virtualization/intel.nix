{ config, lib, pkgs, ... }:

let
  cfg = config.virtualization.intel; 
in
{
  options.virtualization.intel = {
    enable = lib.mkEnableOption "intel virtualization";
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernelParams = [ "intel_iommu=on" ];
      initrd.kernelModules = [ "kvm_intel" ];
      extraModprobeConfig = ''
        options kvm_intel nested=1 
      '';
    };

    hardware.cpu.intel.updateMicrocode = true;
  };
}