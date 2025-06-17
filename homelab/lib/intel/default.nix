{ config, lib, pkgs, ... }:

{
  imports = [
    ./graphics.nix
    ./undervolt.nix
  ];
}
