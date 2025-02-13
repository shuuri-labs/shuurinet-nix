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
      default = [ "intel_iommu=on" "iommu=pt" ];
      description = "Additional kernel parameters for IOMMU.";
    };

    extraModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "vfio_iommu_type1" "vfio_pci" "kvm_intel" ];
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
      onShutdown = "shutdown"; # shutdown the VMs when the host shuts down
      qemu = {
        package = pkgs.qemu_kvm;

        ovmf = {
          enable = true;  # Enable UEFI support
          packages = [ pkgs.OVMFFull.fd ]; 
        };

        # verbatimConfig = ''
        #   user = "root"
        #   group = "root"
        #   cgroup_device_acl = [
        #     "/dev/null", "/dev/full", "/dev/zero",
        #     "/dev/random", "/dev/urandom",
        #     "/dev/ptmx", "/dev/kvm",
        #     "/dev/vfio/vfio",
        #     "/dev/vfio/0",  # Add IOMMU group devices
        #     "/dev/vfio/1"
        #   ]
        # '';
      };
      
    };

    # PCIe passthrough
    hardware.cpu.intel.updateMicrocode = true;
  };
}