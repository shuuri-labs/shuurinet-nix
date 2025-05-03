{ lib, pkgs, ... }@args:

let
  helpers = import ./helpers.nix { inherit lib pkgs; };
  options = import ./options.nix { inherit lib; };
  impl    = import ./main.nix (args // {
    inherit helpers;
  });
in
{
  options = options;
  config  = impl.config;
}