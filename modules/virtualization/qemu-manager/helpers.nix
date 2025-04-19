{ lib, pkgs }:

rec {
  mkBridgeArgs = bridges:
    lib.flatten (lib.imap0 (idx: br: [
      "-netdev" "bridge,id=net${toString idx},br=${br}"
      "-device" "virtio-net-pci,netdev=net${toString idx}"
    ]) bridges);

  mkPciPassthroughArgs = hosts:
    lib.concatMap (h: [ "-device" "vfio-pci,host=${h.address}" ]) hosts;

  mkUsbPassthroughArgs = hosts:
    lib.concatMap (h: [ "-device"
      "usb-host,vendorid=${h.vendorId},productid=${h.productId}" ]) hosts;

  mkExtraArgs = extra: lib.concatMap (a: [ "-${a}" ]) extra;

  mkUefiArgs = name: enable: let
    code     = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
    varsFile = "/var/lib/libvirt/images/${name}-ovmf-vars.fd";
  in
    lib.optional enable "-drive if=pflash,format=raw,readonly=on,file=${code}"
  ++ lib.optional enable "-drive if=pflash,format=raw,file=${varsFile}";

  mkUefiPreStart = name: enable: lib.optional enable ''
    ${pkgs.coreutils}/bin/install -m0644 -o root -D \
      ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd /var/lib/libvirt/images/${name}-ovmf-vars.fd
  '';

  prettyArgs = args: lib.concatStringsSep " \\\n  " args;
}
