{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  apBase = import ../base/ap.nix;
  ax6sBase = import ../base/ax6s.nix;
in
  inputs.openwrt-imagebuilder.lib.build (apBase.mkApConfig {
    hostname = "shuurinet-AP";
    ipAddress = "192.168.11.3";
  } // ax6sBase.mkAx6sConfig {
  })