{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  routerBase = import ../base/router.nix { inherit inputs; };
  ax6sBase = import ../base/ax6s.nix { inherit inputs; };
  
  # Router configuration parameters
  routerArgs = {
    hostname = "shuurinet-router-ldn";
    ipAddress = "192.168.10.1";
    # sqmConfig = {
    #   queue = "eth4";
    #   interface = "eth4";
    #   enabled = true;
    #   download = 178000;
    #   upload = 44000;
    #   linklayer = "ethernet";
    #   overhead = 34;
    # };
  };
  
  # Create the configuration by combining router and AX6S configs
  config = routerBase.mkRouterConfig routerArgs // ax6sBase.mkAx6sConfig {};
  
  # Build the image
  image = inputs.openwrt-imagebuilder.lib.build config;
in
  image // { inherit config; }