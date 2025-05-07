## OpenWRT Image Builder/Extractor

This is a wrapper for the OpenWRT image builder derivation. It takes the output of that derivation and outputs a single file, since the derivation itself outputs a folder full of various formats (ext4, squashfs etc). 

To build an image, first run nix flake update to update OpenWRT hashes, or you might get: `hash mismatch in fixed-output derivation`

#### Overcoming Outdated Hashes

Sometimes, their build lags behind and you made need to update the hashes yourself. that's why you cloned a copy of the `nix-openwrt-imagebuilder` repo in your config repo's `/lib`. If it's not there, clone it again and do: 
```
# (from inside cloned repo, to make pulling latest easier)
git remote add upstream https://github.com/astro/nix-openwrt-imagebuilder.git
```

To update and use the local hashes, cd in `lib/nix-openwrt-imagebuilder` and run: 
`git reset --hard`
`git pull`
`nix run .#generate-hashes $(sed -e 's/"//g' latest-release.nix)` or `nix run .#generate-all-hashes` 
(the latter may take a while).


you should now be able to re-run your host rebuild with: 
```
# (from root of your nix config repo, where flake file is)
IB=$(realpath ~/shuurinet-nix/lib/nix-openwrt-imagebuilder)
# then: 
nxrb --impure --override-input openwrt-imagebuilder "git+file://$IB"`
```

To just test if the image itself builds, you can do:
`nix build "#berlin-router-img"  --impure --override-input openwrt-imagebuilder "git+file://$IB"`


##### Flake input
Flake input is tied to a specific commit to prevent OpenWRT images rebuilding when the project's hashes get updated. To update/build a new image, update to the latest commit hash (instructions in flake.nix)
