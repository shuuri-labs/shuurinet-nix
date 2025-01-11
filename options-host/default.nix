{ config, lib, pkgs, ... }:
{
  imports = [
    ./paths.nix
    ./access-groups.nix
  ];
}