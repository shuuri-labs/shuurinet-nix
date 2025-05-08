#!/usr/bin/env bash

# FIRST, CHECKOUT A NEW BRANCH FOR THIS HOST NAMED deploy-<hostname>
# Add a /host/<hostname> dir with configuration.nix & disk-configuration.nix
# Update flake.nix to include the new host
# git commit + git push --set-upstream origin deploy-<hostname>
# Then run this script

# NOTE: If using virtualisation module, comment it out in config before running this script

read -p "Enter target hostname: " TARGET_HOST
read -p "Enter taget IP address: " TARGET_IP
read -p "Enter github token (saved in bitwarden): " GITHUB_TOKEN

# Create local temp dir to be copied to host and purge on script end
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

install -d -m755 "$temp/etc/ssh"
install -d -m755 "$temp/home/ashley/shuurinet-nix/secrets"
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

HOST_KEY=$(cat "$temp/etc/ssh/ssh_host_ed25519_key.pub")
USER_KEY=$(cat "$temp/home/ashley/.ssh/id_ed25519.pub")

# Check if host key already exists on github and delete it if so
EXISTING_KEY=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user/keys \
  | jq '.[] | select(.title == "My Key") | .id')

if [ -n "$EXISTING_KEY" ]; then
  curl -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
       https://api.github.com/user/keys/$EXISTING_KEY
fi

# Add new user key to github
jq -n --arg title "ashley@$TARGET_HOST" --arg key "$USER_KEY" \
  '{title: $title, key: $key}' | \
  curl -H "Authorization: token $GITHUB_TOKEN" \
       -H "Content-Type: application/json" \
       -d @- https://api.github.com/user/keys

# Show host public key for agenix
echo -e "\nCopy into secrets/secrets.nix:"
echo "$TARGET_HOST = \"$HOST_KEY\";"
echo "$TARGET_HOST-user = \"$USER_KEY\";"
echo -e "\nAdd new hosts to secrets = [ ... ]:"
echo " $TARGET_HOST $TARGET_HOST-user "
echo -e "\nRun secrets/rekey-new-host.sh, and then press Enter to continue with deployment..."
read -r

# Copy secrets only (full config is copied in post-deployment-bootstrap module), exclude .DS_Store if running on MacOS
rsync -av --exclude '.DS_Store' ~/shuurinet-nix/secrets/. "$temp/home/ashley/shuurinet-nix/secrets"

# Set file permissions for copied host keys
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"
chmod 644 "$temp/etc/ssh/ssh_host_ed25519_key.pub"

# Set file permissions for copied user keys. user and group id for ashley are defined in common module
chmod 600 "$temp/home/ashley/.ssh/id_ed25519"
chmod 644 "$temp/home/ashley/.ssh/id_ed25519.pub"

# Set file permissions for copied nix config dir
chmod -R 755 "$temp/home/ashley/shuurinet-nix"

# Note the chown user/group will not propagate to the remote host, but we can use the --chown flag in the nixos-anywhere command (see below)
# 1000:985 are the UID/GID set for ashley:ashley in shuurinet-nix/common/default.nix

# Deploy to remote Linux machine, pinned to older commit atm because --build-on-remote is currently broken
nix run github:nix-community/nixos-anywhere/9afe1f9fa36da6075fdbb48d4d87e63456535858 -- \
--build-on-remote \
--flake ".#${TARGET_HOST}" \
--target-host "root@${TARGET_IP}" \
--build-on-remote \
--generate-hardware-config nixos-generate-config "../hosts/${TARGET_HOST}/hardware-configuration.nix" \
--extra-files "$temp" \
--option pure-eval false \
--chown /home/ashley/.ssh 1000:985 \
--chown /home/ashley/shuurinet-nix 1000:985