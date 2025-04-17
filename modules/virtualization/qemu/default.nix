{ config, lib, pkgs, ... }:
{
  imports = [
    ./convert-images.nix
    ./make-vm-service.nix
  ];    
}