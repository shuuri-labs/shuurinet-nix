{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  
  base = import ./base.nix { inherit inputs; };

  mkAx6sConfig = args@{ 
    target ? "mediatek/mt7622",
    variant ? "generic",
    profile ? "xiaomi_redmi-router-ax6s",
    release ? "snapshot",
    ...
  }: base.mkBaseConfig (args // {
    inherit target variant profile release;
  });

in {
  inherit mkAx6sConfig;
}