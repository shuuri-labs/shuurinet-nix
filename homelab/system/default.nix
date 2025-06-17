{ config, pkgs, lib, ... }:
{
  imports = [
    ./disk
    ./networking
    ./storage
  ];
}