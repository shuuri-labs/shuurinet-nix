{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  x86RouterBase = import ../base/x86-router.nix { inherit inputs; };
  
  # Router configuration parameters
  routerArgs = {
    hostname = "shuurinet-router-ldn";
    ipAddress = "10.11.20.51";
    gateway = "10.11.20.1";
    dnsServer = "10.11.20.1";
  };
  
  # Create the configuration
  config = x86RouterBase.mkX86RouterConfig routerArgs;

  # Build the image with the config attached
  image = inputs.openwrt-imagebuilder.lib.build config;
in
  image // { inherit config; }