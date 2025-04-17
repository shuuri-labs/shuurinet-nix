{ config, lib, pkgs, ... }:
{
  imports = [
    ./images.nix
    ./services.nix
  ];    
}