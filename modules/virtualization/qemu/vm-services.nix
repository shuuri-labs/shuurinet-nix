{ config, lib, pkgs, ... }:

let
  mkBridgeArgs = {
    bridges,
    ...
  }:
    builtins.concatStringsSep " \\\n" (lib.imap0 
      (idx: bridge: ''
        -netdev bridge,id=net${toString idx},br=${bridge} \
        -device virtio-net-pci,netdev=net${toString idx} \
      '') 
      bridges);

  mkPciPassthroughArgs = {
    hosts,
    ...
  }:
    builtins.concatStringsSep " \\n" (builtins.map 
      (host: "-device pci-assign,host=${host} \\") 
      hosts);

  usbHost = lib.types.submodule {
    options = {
      vendorId = lib.mkOption {
        type = lib.types.str;
        description = "USB device vendor ID (e.g., '0x0483')";
        example = "0x0483";
      };
      productId = lib.mkOption {
        type = lib.types.str;
        description = "USB device product ID (e.g., '0x5740')";
        example = "0x5740";
      };
    };
  };

  mkUsbPassthroughArgs = {
    hosts,
    ...
  }:
    builtins.concatStringsSep " \\n" (builtins.map 
      (host: "-device usb-host,vendorid=${host.vendorId},productid=${host.productId} \\") 
      hosts);

  mkExtraArgs = {
    extraArgs,
    ...
  }:
    builtins.concatStringsSep " \\n" (builtins.map (arg: "-${arg} \\") extraArgs);

  cfg = config.virtualisation.qemu.VmServices;
in {
  options.virtualisation.qemu.VmServices = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "QEMU virtual machine";
        
        imagePath = lib.mkOption {
          type = lib.types.path;
          description = "Path to VM disk image";
        };

        memory = lib.mkOption {
          type = lib.types.ints.positive;
          default = 512;
          description = "Memory in MB";
        };

        smp = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
          description = "Number of CPU cores";
        };

        format = lib.mkOption {
          type = lib.types.str;
          default = "qcow2";
          description = "Disk image format";
        };

        bridges = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "br0" ];
          description = "List of network bridges";
        };

        pciHosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "PCI devices to pass through";
          example = [
            "00:01.0"
          ];
        };

        usbHosts = lib.mkOption {
          type = lib.types.listOf usbHost;
          default = [];
          description = "USB devices to pass through";
          example = [
            { vendorId = "0x0483"; productId = "0x5740"; }
          ];
        };

        vncPort = lib.mkOption {
          type = lib.types.ints.between 0 9;
          description = "Last digit of VNC port (590X)";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Additional QEMU arguments";
          example = [
            "device virtio-vga"
          ];
        };

        restart = lib.mkOption {
          type = lib.types.str;
          default = "always";
          description = "VM service restart policy";
        };
      };
    });
    default = {};
    description = "QEMU VM services configuration";
    example = {
      vm1 = {
        enable = true;
        imagePath = "/var/lib/vms/images/vm1.qcow2";
        memory = 1024;
        smp = 4;
        format = "qcow2";
        bridges = [ "br0" ];
        pciHosts = [ "00:01.0" ];
        usbHosts = [ { vendorId = "0x0483"; productId = "0x5740"; } ];
        vncPort = 1;
        extraArgs = [ "device virtio-vga" ];
      };
    };
  };

  config = lib.mkIf (cfg != {}) {
    # Add all bridges for VMs to libvirtd allowedBridges (/etc/qemu/bridge.conf)
    # virbr0 is the default value, not sure what happens if we don't re-add it 
    virtualisation.libvirtd.allowedBridges = [ "virbr0" ] ++ lib.unique (
      lib.flatten (
        lib.mapAttrsToList (_: vmConfig: vmConfig.bridges) cfg
      )
    );
    
    systemd.services = lib.mapAttrs (name: vmConfig: 
      lib.mkIf vmConfig.enable {
        description = "QEMU VM: ${name}";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = vmConfig.restart;
          ExecStart = ''
            ${pkgs.qemu}/bin/qemu-system-x86_64 \
              -enable-kvm \
              -machine q35 \
              -cpu host \
              -m ${toString vmConfig.memory} \
              -smp ${toString vmConfig.smp} \
              -drive file=${vmConfig.imagePath},if=virtio,format=${vmConfig.format} \
              -device usb-ehci \
              -device usb-tablet \
              ${mkBridgeArgs vmConfig.bridges}
              ${mkPciPassthroughArgs vmConfig.pciHosts}
              ${mkUsbPassthroughArgs vmConfig.usbHosts}
              ${mkExtraArgs vmConfig.extraArgs}
              -device virtio-vga \
              -vnc :${toString vmConfig.vncPort} \
              -serial unix:/tmp/${name}-console.sock,server,nowait 
          '';
        };
      };
    ) cfg;

    # create 'vmName-console' alias for each VM for accessing the serial console
    environment.shellAliases = lib.mapAttrs' (name: _: {
      name = "${name}-console";
      value = "socat UNIX-CONNECT:/tmp/${name}-console.sock stdio";
    }) cfg;
  };
}