{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  routerBase = import ../base/router.nix;
  ax6sBase = import ../base/ax6s.nix;
in
  inputs.openwrt-imagebuilder.lib.build (routerBase.mkRouterConfig {
    hostname = "shuurinet-router";
    ipAddress = "192.168.11.51";
    # sqmConfig = {
    #   queue = "eth4";
    #   interface = "eth4";
    #   enabled = true;
    #   download = 178000;
    #   upload = 44000;
    #   linklayer = "ethernet";
    #   overhead = 34;
    # };
  } // ax6sBase.mkAx6sConfig {
  })