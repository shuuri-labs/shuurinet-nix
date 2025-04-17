{ config, lib, pkgs, ... }:

let
  cfg = config.virtualization;
in
{
  imports = [
    ./base.nix
    ./bare-metal.nix
    ./intel.nix
    # ./nixvirt.nix
    ./make-qemu-vm-service.nix
  ];

  config = {
    virtualization.enable = cfg.bareMetal.enable || cfg.intel.enable || cfg.nixvirt.enable;
    virtualization.bareMetal.enable = cfg.intel.enable;
  };
}


