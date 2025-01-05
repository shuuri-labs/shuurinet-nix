{ config, lib, ... }:

{
  imports = [
    ./paths.nix
    ./zfs.nix
    ./hdd-spindown.nix
  ];
}
