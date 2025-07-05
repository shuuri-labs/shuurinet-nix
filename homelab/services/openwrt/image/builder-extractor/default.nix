{ inputs }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  base = import ./base.nix { inherit inputs; };

  mkImageExtractor = { name, 
                      imageDefinition, 
                      format ? "ext4-combined-efi",
                      imageFormat ? "img",
                      compressedFormat ? "gz"
                    }:
    let
      inherit (imageDefinition.config) release target variant profile;
      
      imageName  = "openwrt-${release}-${target}-${variant}-${profile}-${format}.${imageFormat}.${compressedFormat}";
      outputName = "${name}.${imageFormat}.${compressedFormat}";
    in pkgs.runCommand outputName { src = imageDefinition; } ''
         cp $src/${imageName} $out
       '';
in
{
  inherit mkImageExtractor;
}