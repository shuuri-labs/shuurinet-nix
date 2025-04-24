{ config, lib, pkgs, helpers, ... }:

let
  cfg            = config.virtualisation.qemu.manager.services;
  bridgeNames    = lib.unique (lib.flatten (lib.mapAttrsToList (_: v: v.bridges) cfg));
  vncPorts       = map (n: 5900 + n) (lib.collect lib.isInt (lib.mapAttrsToList (_: v: v.vncPort) cfg));
  pciIds         = lib.concatStringsSep "," (
                     lib.flatten (lib.mapAttrsToList (_: v:
                       lib.map (h: h.vendorDeviceId) v.pciHosts) cfg));
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
      options vfio-pci ids=${pciIds}
    '';

    # ensure overlay dir exists
    systemd.tmpfiles.rules = [ "d ${cfg.imageOverlayDir} 0755 root root - -" ];

    # so we can parse /etc/qemu-images.json and do console aliases
    environment.systemPackages = [ pkgs.socat pkgs.jq ];

    systemd.services = lib.mapAttrs (name: v: lib.mkIf v.enable {
      description = "QEMU VM: ${name}";
      wantedBy    = [ "multi-user.target" ];

      # Add these lines to make the service depend on the image
      path = [ pkgs.qemu pkgs.jq pkgs.socat ];
      restartTriggers = [ 
        config.virtualisation.qemu.manager.builtImages.${v.baseImage} 
        (config.virtualisation.qemu.manager.builtImages.${v.baseImage}).drvPath
      ];

      serviceConfig = {
        Type    = "simple";
        Restart = v.restart;

        ReadWritePaths = [ "${cfg.imageOverlayDir}" ];

        # Add a hash file alongside the overlay
        ExecStartPre = let
          script = ''
            # Run UEFI setup commands if any
            ${helpers.mkUefiPreStart name v.uefi}

            # Create overlay
            base=$(${pkgs.jq}/bin/jq -r ".${v.baseImage}.path" /etc/qemu-images.json)
            if [ "$base" = "null" ]; then
              echo "Error: No path specified for base image '${v.baseImage}'" >&2
              exit 1
            fi

            # All our converted images are qcow2 format
            format=$(${pkgs.jq}/bin/jq -r ".${v.baseImage}.format" /etc/qemu-images.json)
            if [ "$format" = "null" ]; then
              format="qcow2"  # default to qcow2 if not specified
            fi

            overlay=${cfg.imageOverlayDir}/${name}.qcow2

            if [ ! -f "$overlay" ] || [ "$base" -nt "$overlay" ]; then
              mkdir -p "$(dirname "$overlay")"
              ${pkgs.qemu}/bin/qemu-img create \
                -f qcow2 \
                -F "$format" \
                -b "$base" \
                "$overlay"
            fi
          '';
        in pkgs.writeShellScript "qemu-${name}-pre.sh" script;

        # 2) launch QEMU against that overlay
        ExecStart = ''
          ${pkgs.qemu}/bin/qemu-system-x86_64 \
            ${helpers.prettyArgs (
              # pflash drives if UEFI
              helpers.mkUefiArgs name v.uefi

              # root disk: virtio vs SCSI
              ++ (if v.rootScsi then [
                   "-device" "virtio-scsi-pci"
                   "-drive"  "file=${cfg.imageOverlayDir}/${name}.qcow2,if=none,id=drive0,format=qcow2"
                   "-device" "scsi-hd,drive=drive0"
                 ] else [
                   "-drive" "file=${cfg.imageOverlayDir}/${name}.qcow2,if=virtio,format=qcow2"
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
    }) cfg;

    # console aliases
    environment.shellAliases = lib.mapAttrs' (n: _: {
      name  = "${n}-console";
      value = "socat UNIX-CONNECT:/tmp/${n}-console.sock stdio";
    }) cfg;
  };
}