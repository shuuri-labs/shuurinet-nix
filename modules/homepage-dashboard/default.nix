{ config, lib, pkgs, ... }:
{
  config = {
    services.homepage-dashboard = {
      enable = true;
      openFirewall = true;
    };
  };
}