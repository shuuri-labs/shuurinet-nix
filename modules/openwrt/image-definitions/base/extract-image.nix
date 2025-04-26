{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  base = import ./base.nix { inherit inputs; };

  # Function to extract a specific image format from any OpenWRT image derivation
  mkImageExtractor = {
    name,  # Name for the extracted image derivation
    imageDerivation,  # The OpenWRT image derivation to extract from
    format ? "ext4-combined-efi", 
    imageFormat ? "img",
    compressedFormat ? "gz" # The image format to extract
  }:
    let
      # Get the version, target, variant, and profile from the image derivation's config
      inherit (imageDerivation.config) release target variant profile;

      imageName = "openwrt-${release}-${target}-${variant}-${profile}-${format}.${imageFormat}.${compressedFormat}";
      outputName = "${name}.${imageFormat}.${compressedFormat}";
    in
      pkgs.runCommand outputName {
        src = imageDerivation;
      } ''
        cp $src/${imageName} $out
      '';
in {
  inherit mkImageExtractor;
} 