{ config, lib, pkgs, ... }:
{
  imports = [
    ./config.nix
    ./static-ip.nix
  ];
}