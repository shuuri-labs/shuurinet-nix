{ lib }:

let
  usbHost = lib.types.submodule {
    options = {
      vendorId  = lib.mkOption { type = lib.types.str; };
      productId = lib.mkOption { type = lib.types.str; };
    };
  };

  pciHost = lib.types.submodule {
      options = {
        address         = lib.mkOption { type = lib.types.str; };
        vendorDeviceId  = lib.mkOption { type = lib.types.str; default = ""; };
    };
  };
in
{
  virtualisation.qemu.manager = {
    services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
      options = {
        enable    = lib.mkEnableOption "QEMU virtual machine";
        baseImage = lib.mkOption { type = lib.types.str; };
        imageOverlayDir = lib.mkOption { type = lib.types.str; default = "/var/lib/vm/images"; };
        rootScsi  = lib.mkOption { type = lib.types.bool; default = false; };
        uefi      = lib.mkOption { type = lib.types.bool; default = false; };
        memory    = lib.mkOption { type = lib.types.ints.positive; default = 512; };
        smp       = lib.mkOption { type = lib.types.ints.positive; default = 2; };
        format    = lib.mkOption { type = lib.types.str; default = "qcow2"; };
        bridges   = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
        pciHosts  = lib.mkOption { type = lib.types.listOf pciHost; default = []; };
        usbHosts  = lib.mkOption { type = lib.types.listOf usbHost; default = []; };
        vncPort   = lib.mkOption { type = lib.types.ints.between 0 9; };
        extraArgs = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
        restart   = lib.mkOption { type = lib.types.str; default = "always"; };
      };
    }));
    default = {};
  };
}
