{ config, lib, pkgs, ... }:

{
 imports = [  
   ./accessGroups.nix
   ./users.nix
   ../host/drives-filesystems/paths.nix
 ];
}
