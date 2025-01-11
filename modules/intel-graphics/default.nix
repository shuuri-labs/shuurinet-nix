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
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
    };

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
        vaapiVdpau
        intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
        intel-media-sdk # QSV up to 11th gen
      ];
    };
  };
}