#!/usr/bin/env bash

cd ~/shuurinet-nix/lib

# remove repo if it exists
rm -rf nix-openwrt-imagebuilder

# clone repo
git clone https://github.com/astro/nix-openwrt-imagebuilder.git

cd ~/shuurinet-nix/homelab/lib/openwrt/image/builder-extractor

# fetch latest hashes
nix run .#generate-hashes $(sed -e 's/"//g' latest-release.nix)

# set path to repo as variable
IB=$(realpath ~/shuurinet-nix/homelab/lib/openwrt/image/builder-extractor)