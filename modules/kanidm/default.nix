{ config, lib, pkgs, ... }:

{
  options = {
    enable = lib.mkEnableOption "kanidm";
  };

  config = lib.mkIf config.enable {
    services.kanidm = {
      enable = true;
    };
  };
}
