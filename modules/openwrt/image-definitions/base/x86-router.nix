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

in {
  inherit mkX86RouterConfig;
}