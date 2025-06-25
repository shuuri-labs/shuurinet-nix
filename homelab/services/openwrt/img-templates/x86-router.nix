{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  profiles = inputs.openwrt-imagebuilder.lib.profiles { inherit pkgs; };

  routerBase = import ./router.nix { inherit inputs; };

  mkX86RouterConfig = args@{
    target ? "x86",
    variant ? "64",
    profile ? "generic",
    rootFsPartSize ? 512,
    ...
  }: routerBase.mkRouterConfig (args // {
    inherit target variant profile rootFsPartSize;
  });
  
  # Function to create both config and image for x86 routers
  mkX86RouterImage = args:
    let
      config = mkX86RouterConfig args;
      image = inputs.openwrt-imagebuilder.lib.build config;
    in
      image // { inherit config; };

in {
  inherit mkX86RouterConfig mkX86RouterImage;
}