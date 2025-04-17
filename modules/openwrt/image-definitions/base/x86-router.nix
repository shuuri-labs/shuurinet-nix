{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  routerBase = import ./router.nix { inherit inputs; };

  mkX86RouterConfig = args@{
    target ? "x86",
    variant ? "64",
    profile ? "generic",
    rootFsPartSize ? 1024,
    release ? "24.10.0",
    ...
  }: routerBase.mkRouterConfig (args // {
    inherit target variant profile rootFsPartSize release;
  });

in {
  inherit mkX86RouterConfig;
}