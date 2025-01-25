{ config, lib, pkgs, ... }:

let 
  cfg = config.intelGraphics;
in
{
  options.intelGraphics = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable intel graphics";
    };

    i915.guc_value = lib.mkOption {
      type = lib.types.str;
      default = "2";
      description = ''
        https://wiki.archlinux.org/title/Intel_graphics
        only 2 seems to work for coffee lake
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    boot.kernelParams = [
      "i915.enable_guc=${cfg.i915.guc_value}"
    ];

    environment.systemPackages = with pkgs; [
      intel-gpu-tools
      clinfo
    ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime-legacy1
      ];
    };
  };
}