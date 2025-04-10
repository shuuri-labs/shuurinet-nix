{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  x86RouterBase = import ../base/x86-router.nix { inherit inputs; };
in
  inputs.openwrt-imagebuilder.lib.build (x86RouterBase.mkX86RouterConfig {
    hostname = "shuurin-router";
    ipAddress = "192.168.11.51"; # initial ip address - will be changed by config step
    sqmConfig = {
      queue = "eth4";
      interface = "eth4";
      enabled = true;
      download = 178000;
      upload = 44000;
      linklayer = "ethernet";
      overhead = 34;
    };
  })