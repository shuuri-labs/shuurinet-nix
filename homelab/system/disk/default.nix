{ config, lib, pkgs, ... }:
{
  imports = [
    ./care.nix
    ./spindown.nix
  ];

  # TODO: refactor to use common disk types and options
}