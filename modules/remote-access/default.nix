{ config, pkgs, lib, ... }:

{
  imports = [
    ./ddns.nix
    ./wireguard.nix
  ];
}