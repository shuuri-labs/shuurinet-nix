{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  
  base = import ./base.nix { inherit inputs; };

  # Router-specific configuration builder
  mkRouterConfig = args@{ 
    hostname,
    ipAddress,
    target,
    variant,
    profile,
    rootFsPartSize ? null,
    extraPackages ? [],
    ...
  }: base.mkBaseConfig (args // {
    extraPackages = [
      "avahi-daemon-service-http"
      "avahi-daemon-service-ssh"
      "luci-app-sqm"
    ] ++ extraPackages;
    inherit rootFsPartSize;
  });
  
  # Function to create both router config and image
  mkRouterImage = args:
    let
      config = mkRouterConfig args;
      image = inputs.openwrt-imagebuilder.lib.build config;
    in
      image // { inherit config; };

in {
  inherit mkRouterConfig mkRouterImage;
}