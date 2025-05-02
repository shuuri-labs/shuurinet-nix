{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  
  # Update all hashes for the openwrt-imagebuilder
  updatedOpenwrtBuilder = pkgs.runCommand "updated-openwrt-builder" {} ''
    cp -r ${inputs.openwrt-imagebuilder} $out
    chmod -R +w $out
    cd $out
    ${pkgs.nixFlakes}/bin/nix run --impure $out#generate-all-hashes
  '';
  
  # Override the openwrt-imagebuilder input
  overriddenInputs = inputs // { openwrt-imagebuilder = updatedOpenwrtBuilder; };
  
  # Import base with the overridden input
  base = import ./base.nix { inputs = overriddenInputs; };

  # Function to extract a specific image format from any OpenWRT image derivation
  mkImageExtractor = {
    name,
    imageDerivation,
    format ? "ext4-combined-efi", 
    imageFormat ? "img",
    compressedFormat ? "gz"
  }:
    let
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