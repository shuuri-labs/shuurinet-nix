{ config, lib, pkgs, ... }:
{
  imports = [
    ./mealie
    ./jellyfin
    ./transmission
    ./media-server
  ];
}