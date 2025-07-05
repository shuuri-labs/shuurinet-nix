## OpenWRT Image Builder/Extractor

This is a wrapper for the OpenWRT image builder derivation. It takes the output of that derivation and outputs a single file, since the derivation itself outputs a folder full of various formats (ext4, squashfs etc). 

To build an image, first updat openwrt-image-builder flake input url commit hash (instructions in flake.nix file), or you might get: `hash mismatch in fixed-output derivation`

#### Overcoming Outdated Hashes

Sometimes, their build lags behind and you may need to clone the repo and fetch the latest hashes yourself. To do this, run the following script: 

`~/shuurinet-nix/homelab/lib/openwrt/image/builder-extractor/fetch-newest-hashes.sh`

you should now be able to re-run your host rebuild with: `nxrbi --override-input openwrt-imagebuilder "git+file://$IB"`

To just test if the image itself builds, you can do:
`nix build "#<image-derivation-name>"  --impure --override-input openwrt-imagebuilder "git+file://$IB"`