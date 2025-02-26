{ config, lib, pkgs, ... }:

let
  cfg = config.virtualization;
in
{
  imports = [
    ./virtualization.nix
    ./bare-metal.nix
    ./intel.nix
    ./nixvirt.nix
  ];

  config = {
    virtualization.enable = cfg.bareMetal.enable || cfg.intel.enable || cfg.nixvirt.enable;
    virtualization.bareMetal.enable = cfg.intel.enable;
  };
}


