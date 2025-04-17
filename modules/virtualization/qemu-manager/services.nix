{ config, lib, pkgs, ... }:

let
  # ------------------------------------------------------------------
  # Helper functions that return **lists** of QEMU CLI arguments
  # ------------------------------------------------------------------

  mkBridgeArgs = bridges:
    lib.flatten (
      lib.imap0 (idx: br: [
        "-netdev" "bridge,id=net${toString idx},br=${br}"
        "-device" "virtio-net-pci,netdev=net${toString idx}"
      ]) bridges
    );

  mkPciPassthroughArgs = hosts:
    lib.concatMap (h: [ "-device" "vfio-pci,host=${h}" ]) hosts;

  mkUsbPassthroughArgs = hosts:
    lib.concatMap (h: [ "-device"
      "usb-host,vendorid=${h.vendorId},productid=${h.productId}" ]) hosts;

  mkExtraArgs = extra: lib.concatMap (a: [ "-${a}" ]) extra;

  # -- UEFI firmware --------------------------------------------------

  mkUefiArgs = name: enable:
    if ! enable then [] else let
      code     = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";   # read‑only image
      varsFile = "/var/lib/libvirt/images/${name}-ovmf-vars.fd";
    in [
      "-drive" "if=pflash,format=raw,readonly=on,file=${code}"
      "-drive" "if=pflash,format=raw,file=${varsFile}"
    ];

  # Ensure the mutable VARS image exists (atomic install)
  mkUefiPreStart = name: enable:
    if ! enable then [] else let
      varsFile = "/var/lib/libvirt/images/${name}-ovmf-vars.fd";
      install  = "${pkgs.coreutils}/bin/install";
      template = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
    in [
      "${install} -m0644 -o root -D ${template} ${varsFile}"
    ];

  # Pretty‑print a list of args into an indented block with back‑slashes
  prettyArgs = args: lib.concatStringsSep " \\\n  " args;

  # ------------------------------------------------------------------
  # Option subtype for USB devices
  # ------------------------------------------------------------------
  usbHost = lib.types.submodule {
    options = {
      vendorId = lib.mkOption {
        type = lib.types.str;
        description = "USB device vendor ID (e.g. '0x0483').";
        example = "0x0483";
      };

      productId = lib.mkOption {
        type = lib.types.str;
        description = "USB device product ID (e.g. '0x5740').";
        example = "0x5740";
      };
    };
  };

  cfg = config.virtualisation.qemu.manager.services;

in {
  # ------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------
  options.virtualisation.qemu.manager.services = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "QEMU virtual machine";

        imagePath = lib.mkOption {
          type = lib.types.path;
          description = "Path to VM disk image.";
        };

        rootScsi = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Expose the main drive via virtio‑SCSI (adds virtio‑scsi‑pci + scsi‑hd).";
        };

        uefi = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Boot the VM with OVMF UEFI firmware (adds two pflash drives).";
        };

        memory = lib.mkOption {
          type = lib.types.ints.positive;
          default = 512;
          description = "Memory in MB.";
        };

        smp = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
          description = "Number of CPU cores.";
        };

        format = lib.mkOption {
          type = lib.types.str;
          default = "qcow2";
          description = "Disk image format.";
        };

        bridges = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "br0" ];
          description = "List of network bridges.";
        };

        pciHosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "PCI devices to pass through.";
          example = [ "00:01.0" ];
        };

        usbHosts = lib.mkOption {
          type = lib.types.listOf usbHost;
          default = [];
          description = "USB devices to pass through.";
          example = [
            { vendorId = "0x0483"; productId = "0x5740"; }
          ];
        };

        vncPort = lib.mkOption {
          type = lib.types.ints.between 0 9;
          description = "Last digit of VNC port (590X).";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Additional QEMU arguments (without leading dash).";
          example = [ "device virtio-vga" ];
        };

        restart = lib.mkOption {
          type = lib.types.str;
          default = "always";
          description = "VM service restart policy.";
        };
      };
    });

    default     = {};
    description = "QEMU VM services configuration.";
  };

  # ------------------------------------------------------------------
  # Implementation
  # ------------------------------------------------------------------
  config = lib.mkIf (cfg != {}) {

    # Add every referenced bridge to libvirt's allowedBridges
    virtualisation.libvirtd.allowedBridges =
      [ "virbr0" ] ++
      lib.unique (lib.flatten (lib.mapAttrsToList (_: vm: vm.bridges) cfg));

    # Ensure directory for OVMF vars
    systemd.tmpfiles.rules = [
      "d /var/lib/libvirt/images 0755 root root - -"
    ];

    systemd.services = lib.mapAttrs (name: vmCfg:
      lib.mkIf vmCfg.enable {
        description = "QEMU VM: ${name}";
        wantedBy    = [ "multi-user.target" ];

        serviceConfig = {
          Type    = "simple";
          Restart = vmCfg.restart;

          ExecStartPre = mkUefiPreStart name vmCfg.uefi;

          ExecStart = let
            uefiArgs      = mkUefiArgs name vmCfg.uefi;
            rootDriveArgs = if vmCfg.rootScsi then
              [ "-device" "virtio-scsi-pci"
                "-drive" "file=${vmCfg.imagePath},if=none,id=drive0,format=${vmCfg.format}"
                "-device" "scsi-hd,drive=drive0"
              ] else
              [ "-drive" "file=${vmCfg.imagePath},if=virtio,format=${vmCfg.format}" ];

            baseArgs = [
              "-enable-kvm"
              "-machine" "q35"
              "-cpu" "host"
              "-m"   (toString vmCfg.memory)
              "-smp" (toString vmCfg.smp)
              "-device" "usb-ehci"
              "-device" "usb-tablet"
              "-display" "vnc=:${toString vmCfg.vncPort}"
              "-serial"  "unix:/tmp/${name}-console.sock,server,nowait"
            ];

            allArgs =
              uefiArgs
              ++ rootDriveArgs
              ++ baseArgs
              ++ mkBridgeArgs         vmCfg.bridges
              ++ mkPciPassthroughArgs vmCfg.pciHosts
              ++ mkUsbPassthroughArgs vmCfg.usbHosts
              ++ mkExtraArgs          vmCfg.extraArgs;

          in ''
            ${pkgs.qemu}/bin/qemu-system-x86_64 \
              ${prettyArgs allArgs}
          '';
        };
      }
    ) cfg;

    environment.systemPackages = [ pkgs.socat ];
    environment.shellAliases = lib.mapAttrs' (name: _: {
      name  = "${name}-console";
      value = "socat UNIX-CONNECT:/tmp/${name}-console.sock stdio";
    }) cfg;
  };
}
