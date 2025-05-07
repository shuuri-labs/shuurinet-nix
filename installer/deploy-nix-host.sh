#!/usr/bin/env bash

# Create local temp dir

read -p "Enter target hostname: " TARGET_HOST
read -p "Enter taget IP address: " TARGET_IP

temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

# Create directory structure for initial deployment key

install -d -m755 "$temp/etc/ssh"

# Generate deployment keys directly into temp dir which will be purged on script end

ssh-keygen -t ed25519 \
-C "${TARGET_HOST}@shuurinet" \ # Comment/label for the key
-f "$temp/etc/ssh/ssh_host_ed25519_key" \ # Output filename (will create .pub as well)
-N "" # no passphrase

cp "~/shuurinet-nix/" "$temp/home/ashley/shuurinet-nix/"

chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"
chmod 644 "$temp/etc/ssh/ssh_host_ed25519_key.pub"
chmod 755 "$temp/home/ashley/shuurinet-nix"
chown "$temp/etc/ssh/ssh_host_ed25519_key" 0:0
chown "$temp/etc/ssh/ssh_host_ed25519_key.pub" 0:0
chown "$temp/home/ashley/shuurinet-nix" 1000:985

# Show public key for agenix

echo -e "\nPublic key for agenix:"
cat "$temp/etc/ssh/ssh_host_ed25519_key.pub"
echo -e "\nRekey your secrets with this public key, commit, add, and then press Enter to continue with deployment..."
read -r

# Deploy to remote Linux machine

nix run github:nix-community/nixos-anywhere -- \
--build-on-remote \
--flake ".#${TARGET_HOST}" \
--target-host "root@${TARGET_IP}" \
--generate-hardware-config nixos-generate-config "../hosts/${TARGET_HOST}/hardware-configuration.nix" \
--extra-files "$temp"