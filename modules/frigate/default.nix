{ config, lib, ... }:

let
  cfg = config.frigate;
in
{
  options.frigate = {
    enable = lib.mkEnableOption "frigate";

    vaapiDriver = lib.mkOption {
      type = lib.types.str;
      default = "intel-media-driver";
    };

  };

  config = lib.mkIf config.services.frigate.enable {
    services.frigate = {
      enable = true;
      vaapiDriver = cfg.vaapiDriver;
    };
  };
}