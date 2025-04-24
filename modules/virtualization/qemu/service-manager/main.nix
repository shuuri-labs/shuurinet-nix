{ config, lib, pkgs, helpers, ... }:

let
  cfg            = config.virtualisation.qemu.manager.services;
  bridgeNames    = lib.unique (lib.flatten (lib.mapAttrsToList (_: v: v.bridges) cfg));
  vncPorts       = map (n: 5900 + n) (lib.collect lib.isInt (lib.mapAttrsToList (_: v: v.vncPort) cfg));
  pciIds         = lib.concatStringsSep "," (
                     lib.flatten (lib.mapAttrsToList (_: v:
                       lib.map (h: h.vendorDeviceId) v.pciHosts) cfg));
  imageDirectory = "/var/lib/vm/images";
in {
  options = {};  # all your options live in options.nix

  config = lib.mkIf (cfg != {}) {
    # libvirt / firewall / vfio bits unchanged
    virtualisation.libvirtd.allowedBridges = [ "virbr0" ] ++ bridgeNames;
    networking.firewall.extraCommands = lib.mkAfter ''
      ${lib.concatStringsSep "\n"
        (map (br: ''
          iptables -A FORWARD -i ${br} -j ACCEPT
          iptables -A FORWARD -o ${br} -j ACCEPT
        '') bridgeNames)}
    '';
    networking.firewall.allowedTCPPorts = vncPorts;
    boot.extraModprobeConfig = lib.mkAfter ''
      options vfio‐pci ids=${pciIds}
    '';

    # ensure overlay dir exists
    systemd.tmpfiles.rules = [ "d ${imageDirectory} 0755 root root - -" ];

    # so we can parse /etc/qemu-images.json and do console aliases
    environment.systemPackages = [ pkgs.socat pkgs.jq ];

    systemd.services = lib.mapAttrs (name: v: lib.mkIf v.enable (
    let
      # precompute the backing-store image for this service
      base   = "${config.virtualisation.qemu.manager.builtImages.${v.baseImage}}/${v.baseImage}.qcow2";
      format = "qcow2";

      preScript = ''
        #!/usr/bin/env bash
        set -euo pipefail

        # 1) UEFI setup if requested
        ${helpers.mkUefiPreStart name v.uefi}

        # 2) Known backing-image path and format
        base='${base}'
        format='${format}'

        # 3) Extract the Nix store hash from the directory name
        baseDir=$(dirname "$base")
        storeHash=$(basename "$baseDir")

        # 4) Construct a hash-specific overlay filename
        realOverlay='${imageDirectory}/${name}-'"$storeHash"'.qcow2'

        # 5) Create that overlay only if it doesn't already exist
        if [ ! -f "$realOverlay" ]; then
          mkdir -p '${imageDirectory}'
          ${pkgs.qemu}/bin/qemu-img create \
            -f qcow2 \
            -F "$format" \
            -b "$base" \
            "$realOverlay"
        fi

        # 6) Atomically update a stable symlink for QEMU to use
        ln -sf "$(basename "$realOverlay")" '${imageDirectory}/${name}.qcow2'
      '';

    in {
      description     = "QEMU VM: ${name}";
      wantedBy        = [ "multi-user.target" ];
      path            = [ pkgs.qemu pkgs.jq pkgs.socat ];

      restartTriggers   = [
        config.virtualisation.qemu.manager.builtImages.${v.baseImage}.drvPath
      ];
      restartIfChanged  = true;

      serviceConfig = {
        Type           = "simple";
        Restart        = v.restart;
        ReadWritePaths = [ imageDirectory ];
        ExecStartPre   = pkgs.writeShellScript "qemu-${name}-pre.sh" preScript;
        ExecStart      = ''
          ${pkgs.qemu}/bin/qemu-system-x86_64 \
            ${helpers.prettyArgs (
              # pflash drives if UEFI
              helpers.mkUefiArgs name v.uefi

              # root disk: virtio vs SCSI
              ++ (if v.rootScsi then [
                   "-device" "virtio-scsi-pci"
                   "-drive"  "file=${imageDirectory}/${name}.qcow2,if=none,id=drive0,format=qcow2"
                   "-device" "scsi-hd,drive=drive0"
                 ] else [
                   "-drive" "file=${imageDirectory}/${name}.qcow2,if=virtio,format=qcow2"
                 ])

              # core machine options
              ++ [
                   "-enable-kvm" "-machine" "q35" "-cpu" "host"
                   "-m" (toString v.memory) "-smp" (toString v.smp)
                   "-device" "usb-ehci" "-device" "usb-tablet"
                   "-display" "vnc=:${toString v.vncPort}"
                   "-serial" "unix:/tmp/${name}-console.sock,server,nowait"
                 ]

              # bridges, PCI & USB passthrough, extra args
              ++ helpers.mkBridgeArgs         v.bridges
              ++ helpers.mkPciPassthroughArgs v.pciHosts
              ++ helpers.mkUsbPassthroughArgs v.usbHosts
              ++ helpers.mkExtraArgs          v.extraArgs
            )}
        '';
      };
    }
    )) cfg;

    # console aliases
    environment.shellAliases = lib.mapAttrs' (n: _: {
      name  = "console-${n}";
      value = "sudo socat UNIX-CONNECT:/tmp/${n}-console.sock stdio";
    }) cfg;
  };
}