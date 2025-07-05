{ config, lib, pkgs, ... }:
{
  imports = [
    ./mealie
    ./jellyfin
    ./jellyseerr
    ./transmission
    ./media-server
    ./immich
    ./paperless
    ./frigate
    ./openwrt
    ./home-assistant
  ];
}