{ config, lib, pkgs, ... }:
{
  imports = [
    ./network
    ./paths-and-groups.nix
  ];
}