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
        i915.enable_guc value
        3 for coffee lake (8th gen) and newer
        https://wiki.archlinux.org/title/Intel_graphics
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "i915.enable_guc=${cfg.i915.guc_value}"
    ];

    environment.sessionVariables = { 
      LIBVA_DRIVER_NAME = "iHD";
    };

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-gpu-tools
        intel-media-driver
        intel-compute-runtime
        vaapiVdpau
        libva-utils
      ];
    };
  };
}

# nix-shell -p intel-gpu-tools --run "sudo intel_gpu_top"