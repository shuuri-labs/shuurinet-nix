#!/usr/bin/env bash

# Prompt for hostname/IP
read -p "Enter target hostname: " TARGET_HOST
read -p "Enter taget IP address: " TARGET_IP

temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

# Set up directory structure
install -d -m755 "$temp/etc/ssh"

# From a file
cp "ssh_keys/${TARGET_HOST}/ssh_host_ed25519_key" "$temp/etc/ssh/ssh_host_ed25519_key"
cp "ssh_keys/${TARGET_HOST}/ssh_host_ed25519_key.pub" "$temp/etc/ssh/ssh_host_ed25519_key.pub"

chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"

# Deploy using nixos-anywhere
nix run github:nix-community/nixos-anywhere -- \
--build-on-remote \
--flake ".#${TARGET_HOST}" \
--target-host "root@${TARGET_IP}" \
--generate-hardware-config nixos-generate-config "../hosts/${TARGET_HOST}/hardware-configuration.nix" \
--extra-files "$temp"