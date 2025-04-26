{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  x86RouterBase = import ../base/x86-router.nix { inherit inputs; };
  
  # Create the configuration
  config = x86RouterBase.mkX86RouterConfig {
    hostname = "shuurinet-router-bln";
    ipAddress = "192.168.11.51";
    gateway = "192.168.11.1";
    dnsServer = "192.168.11.1";
  };

  # Build the image and attach the config
  image = inputs.openwrt-imagebuilder.lib.build config;
in
  image // { inherit config; }