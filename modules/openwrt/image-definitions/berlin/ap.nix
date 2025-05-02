{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  apBase = import ../base/ap.nix { inherit inputs; };
  ax6sBase = import ../base/ax6s.nix { inherit inputs; };
  
  # Router configuration parameters
  apArgs = {
    hostname = "shuurinet-AP-bln";
    ipAddress = "192.168.11.3";
    gateway = "192.168.11.1";
    dnsServer = "192.168.11.1";
  };
  
  # Create the configuration by combining AP and AX6S configs
  config = apBase.mkApConfig apArgs // ax6sBase.mkAx6sConfig {};
  
  # Build the image
  image = inputs.openwrt-imagebuilder.lib.build config;
in
  image // { inherit config; }