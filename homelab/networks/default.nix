{ config, lib, pkgs ... }:
{
  imports = [
    ./networks.nix
    ./config.nix
  ];
}