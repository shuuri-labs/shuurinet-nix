{ config, lib, pkgs, helpers, ... }:

let
  cfg         = config.virtualisation.qemu.manager.services;
  bridgeNames = lib.unique (lib.flatten (lib.mapAttrsToList (_: v: v.bridges) cfg));
  vncPorts    = map (n: 5900 + n) (lib.collect lib.isInt (lib.mapAttrsToList (_: v: v.vncPort) cfg));
  pciIds      = lib.concatStringsSep "," (
                  lib.flatten (lib.mapAttrsToList (_: v: lib.map (h: h.vendorDeviceId) v.pciHosts) cfg));
in
{
  # Return both config and options
  options = {}; # Empty since options are defined in options.nix
  config = lib.mkIf (cfg != {}) {
    # ------------------------------------------------------------------
    # Add to libvirt allowed bridges (/etc/qemu/bridge.conf)
    # ------------------------------------------------------------------
    virtualisation.libvirtd.allowedBridges =
      [ "virbr0" ] ++ bridgeNames;

    # ------------------------------------------------------------------
    # Allow bridge forwarding
    # ------------------------------------------------------------------
    networking.firewall.extraCommands = lib.mkAfter ''
      ${lib.concatStringsSep "\n"
        (map (br: ''
          iptables -A FORWARD -i ${br} -j ACCEPT
          iptables -A FORWARD -o ${br} -j ACCEPT
        '') bridgeNames)}
    '';

    # ------------------------------------------------------------------
    # Open VNC ports
    # ------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = vncPorts;

    # ------------------------------------------------------------------
    # Add vfio-pci module options
    # ------------------------------------------------------------------
    boot.extraModprobeConfig = lib.mkAfter ''
      options vfio-pci ids=${pciIds}
    '';

    # ------------------------------------------------------------------
    # Create directory for VM images
    # ------------------------------------------------------------------
    systemd.tmpfiles.rules = [ "d /var/lib/libvirt/images 0755 root root - -" ];

    # ------------------------------------------------------------------
    # Create systemd service for each VM
    # ------------------------------------------------------------------
    systemd.services = lib.mapAttrs (name: v: lib.mkIf v.enable {
      description = "QEMU VM: ${name}";
      wantedBy    = [ "multi-user.target" ];

      serviceConfig = {
        Type          = "simple";
        Restart       = v.restart;
        ExecStartPre  = lib.concatStringsSep "\n" (helpers.mkUefiPreStart name v.uefi);

        ExecStart = let
          uefiArgs  = helpers.mkUefiArgs name v.uefi;
          rootArgs  = if v.rootScsi then [
            "-device" "virtio-scsi-pci"
            "-drive"  "file=${v.imagePath},if=none,id=drive0,format=${v.format}"
            "-device" "scsi-hd,drive=drive0"
          ] else [
            "-drive" "file=${v.imagePath},if=virtio,format=${v.format}"
          ];

          baseArgs = [
            "-enable-kvm" "-machine" "q35" "-cpu" "host"
            "-m" (toString v.memory) "-smp" (toString v.smp)
            "-device" "usb-ehci" "-device" "usb-tablet"
            "-display" "vnc=:${toString v.vncPort}"
            "-serial"  "unix:/tmp/${name}-console.sock,server,nowait"
          ];

          all = uefiArgs ++ rootArgs ++ baseArgs
                ++ helpers.mkBridgeArgs         v.bridges
                ++ helpers.mkPciPassthroughArgs v.pciHosts
                ++ helpers.mkUsbPassthroughArgs v.usbHosts
                ++ helpers.mkExtraArgs          v.extraArgs;
        in ''
          ${pkgs.qemu}/bin/qemu-system-x86_64 \
            ${helpers.prettyArgs all}
        '';
      };
    }) cfg;

    # ------------------------------------------------------------------
    # Create aliases for each VM console
    # ------------------------------------------------------------------
    environment.systemPackages = [ pkgs.socat ];
    environment.shellAliases   =
      lib.mapAttrs' (n: _: { name = "${n}-console"; value = "socat UNIX-CONNECT:/tmp/${n}-console.sock stdio"; }) cfg;
  };
}