{ config, lib, pkgs, ... }:
{
  imports = [
    ./homelab-networks.nix
    ./config.nix
  ];
}