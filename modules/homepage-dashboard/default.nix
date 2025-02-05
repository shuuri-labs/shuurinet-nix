{ config, lib, pkgs, ... }:
{
  options.homepage-dashboard = {
    enable = lib.mkEnableOption "homepage-dashboard";
  };

  config = lib.mkIf config.homepage-dashboard.enable {
    services.homepage-dashboard = {
      enable = true;
      openFirewall = true;
    };
  };
}