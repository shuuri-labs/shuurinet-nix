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
      kernelParams = [ "intel_iommu=on" "iommu=pt" ];
      initrd.kernelModules = [ "vfio_iommu_type1" "vfio_pci" "kvm_intel" ];
      extraModprobeConfig = ''
        options kvm_intel nested=1 
      '';
    };

    environment.systemPackages = with pkgs; [
      qemu
      libvirt
      spice-gtk # for USB redirection
    ];

    virtualisation.libvirtd = {
      enable = true;
      onShutdown = "shutdown"; # shutdown the VMs when the host shuts down
      qemu = {
        package = pkgs.qemu_kvm;

        ovmf = {
          enable = true;  # Enable UEFI support
          packages = [ pkgs.OVMFFull.fd ]; 
        };
      };
      
    };

    hardware.cpu.intel.updateMicrocode = true;
  };
}