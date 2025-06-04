{ config, lib, pkgs, ... }:
{
  imports = [
    ./common-options.nix
    ./mealie
  ];
}