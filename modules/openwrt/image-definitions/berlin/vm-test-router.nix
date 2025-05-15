{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  x86RouterBase = import ../base/x86-router.nix { inherit inputs; };
  
  # Router configuration parameters
  routerArgs = {
    hostname = "shuurinet-router-bln";
    ipAddress = "192.168.11.51";
    gateway = "192.168.11.1";
    dnsServer = "192.168.11.1";
  };
  
  # Create the configuration
  config = x86RouterBase.mkX86RouterConfig routerArgs;

  # Build the image with the config attached
  image = inputs.openwrt-imagebuilder.lib.build config;
in
  image // { inherit config; }