{ config, lib, pkgs, ... }:
{
  imports = [
    ./mealie
    ./jellyfin
    ./transmission
    ./media-server
    ./paperless
    ./frigate
  ];
}