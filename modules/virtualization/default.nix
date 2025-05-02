{ config, lib, pkgs, ... }:

let
  cfg = config.virtualization;
in
{
  imports = [
    ./base.nix
    ./bare-metal.nix
    ./intel.nix
    ./qemu/service-manager
    ./qemu/image-manager
  ];

  config = {
    virtualization.enable = cfg.bareMetal.enable || cfg.intel.enable;
    virtualization.bareMetal.enable = cfg.intel.enable;
  };
}


