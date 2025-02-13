{ config, lib, pkgs, ... }:

let
  cfg = config.virtualization.intel; 
in
{
  options.virtualization.intel = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable virtualisation support (libvirtd, IOMMU, Intel VT-d and PCIe passthrough)";
    };

    kernelParams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "iommu=on" "iommu=pt" ];
      description = "Additional kernel parameters for IOMMU.";
    };

    extraModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "vfio" "vfio_iommu_type1" "vfio_pci" "kvm" "kvm_intel" ];
      description = "Additional kernel modules to load for virtualization and passthrough.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      # Append required kernel parameters
      kernelParams = cfg.kernelParams;
      # Load required kernel modules
      initrd.kernelModules = cfg.extraModules;

      # 'vfio-pci ids=' will block specific devices from the host and immediately pass them through on boot 
      #  (get device ids from lspci -nn, at end of each line is [vendorId:deviceId])
      # 'kvm_intel nested=1' enables nested virtualization
      extraModprobeConfig = ''
        options vfio-pci ids=15b3:1015
        options kvm_intel nested=1 
      '';
    };

    # Required packages for virtualization
    environment.systemPackages = with pkgs; [
      qemu
      libvirt
      virt-manager
      spice-gtk # for USB redirection
    ];

    # Enable libvirtd service
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      qemu = {
        ovmf = {
          enable = true;  # Enable UEFI support
          packages = [ pkgs.OVMFFull.fd ]; 
        };
        swtpm.enable = true; # Enable TPM emulation
      };
    };

    # PCIe passthrough
    hardware.cpu.intel.updateMicrocode = true;
  };
}