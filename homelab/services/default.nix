{ config, lib, pkgs, ... }:
{
  imports = [
    ./mealie
    ./jellyfin
  ];
}