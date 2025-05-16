{ config, lib, pkgs, ... }:
let
  cfg = config.homepage-dashboard;
in
{
  options.homepage-dashboard = {
    enable = lib.mkEnableOption "homepage-dashboard";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };
  };
}