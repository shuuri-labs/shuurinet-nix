#!/usr/bin/env bash

read -p "Enter target hostname: " TARGET_HOST
read -p "Enter taget IP address: " TARGET_IP

# Create local temp dir to be copied to host and purge on script end
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

install -d -m755 "$temp/etc/ssh"
install -d -m755 "$temp/home/ashley/shuurinet-nix"
install -d -m700 "$temp/home/ashley/.ssh"

# Generate deployment keys directly into temp dir which will copied to host
ssh-keygen -t ed25519 \
    -C "${TARGET_HOST}@shuurinet" \
    -f "$temp/etc/ssh/ssh_host_ed25519_key" \
    -N ""

# Generate and copy user keys
ssh-keygen -t ed25519 \
    -C "ashley@${TARGET_HOST}.shuurinet" \
    -f "$temp/home/ashley/.ssh/id_ed25519" \
    -N ""

# Show host public key for agenix
echo -e "\nPublic key for agenix:"
cat "$temp/etc/ssh/ssh_host_ed25519_key.pub"
echo -e "\nRekey your secrets with this public key, commit, add, and then press Enter to continue with deployment..."
read -r

# Show user public key for github
echo -e "\nPublic key user"
cat "$temp/home/ashley/.ssh/id_ed25519.pub"
echo -e "\nAdd to key github and press Enter to continue with deployment..."
read -r

# Copy the configuration
rsync -av --exclude '.DS_Store' ~/shuurinet-nix/. "$temp/home/ashley/shuurinet-nix"

# Set file permissions for copied host keys
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"
chmod 644 "$temp/etc/ssh/ssh_host_ed25519_key.pub"
chown 0:0 -R "$temp/etc/ssh"

# Set file permissions for copied user keys. user and group id for ashley are defined in common module
chmod 600 "$temp/home/ashley/.ssh/id_ed25519"
chmod 644 "$temp/home/ashley/.ssh/id_ed25519.pub"
chown 1000:985 -R "$temp/home/ashley/.ssh"

# Set file permissions for copied nix config dir
chmod -R 755 "$temp/home/ashley/shuurinet-nix"
chown -R 1000:985 "$temp/home/ashley/shuurinet-nix"

# Deploy to remote Linux machine, pinned to older commit atm because --build-on-remote is currently broken
nix run github:nix-community/nixos-anywhere/9afe1f9fa36da6075fdbb48d4d87e63456535858 -- \
--build-on-remote \
--flake ".#${TARGET_HOST}" \
--target-host "root@${TARGET_IP}" \
--build-on-remote \
--generate-hardware-config nixos-generate-config "../hosts/${TARGET_HOST}/hardware-configuration.nix" \
--extra-files "$temp" \
--option pure-eval false