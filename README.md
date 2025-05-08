## Deployment Instructions

#### Checkout a new deployment branch 

```bash
# name format is important! must be as below
git checkout -b deploy-<host_name>
```

If you don't have one handy, go to `~/shuurinet-nix/installer/custom-iso.nix` and follow the instructions to create a custom ISO with the required ssh keys. If you're deploying to a Linux machine sans-ISO, then you must have root access (ssh and password) to the target machine.

#### Get the host's current IP & boot drive uuid
```bash
# Create a nixos installer usb key and boot, then do: 
ip a

lsblk # take note of /dev/sdX deligation of boot drive
ls -l /dev/disk/by-id # find id for sdX designation from above
```

#### Create Host Config

Create a `configuration.nix` and a `disk-config.nix` in `~/shuurinet-nix/hosts`. Set the boot disk id in the `device` field of the disk config. Import disk config into main configuration (see repo for examples).

```nix
{ lib, ... }:
{
  disko.devices = {
    disk.disk1 = {
      device = "/dev/disk/by-id/<BOOT_DISK_ID_HERE>
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            name = "ESP";
            size = "1G";  # Increased from 500M for better future-proofing
            type = "EF00"; # EFI System Partition type
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "pool";
            };
          };
        };
      };
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
            };
          };
        };
      };
    };
  };
}
```

Don't forget to add the new host to `flake.nix`, too!
#### Commit and push new branch

```bash
git add *
git commit -m "Deploying <host>"
git push
```
#### Run installer script

Run the installer in `shuurinet-nix/installer/deploy-nix-host.sh`. Enter hostname (as defined in flake), IP address (of the current installation/installer) and Github access token (saved in your Bitwarden!) Follow the script's instructions. Host user key will automatically be added to github via API call. When adding keys to `~/shuurinet-nix/secrets/secrets.nix`, just add the keys and the new hosts to `systems = [ ... ]`. The script will take care or re-keying, committing and pushing.
#### Post-Install Bootstrap Service

Service/module called `git-clone-config` will take care of git cloning config into `~/`. It will pull the deployment branch, which is why it's important to create one with the name format described above. If no deployment branch can be found, however, it will simply pull `develop`.

The service will only run once - it checks if `~/shuurinet-nix` contains _only_ the `secrets` directory. If so, it knows that this is a fresh deployment, and will overwrite the config repo with the cloned git repo. 
#### Router-Specific 

If deploying your router, update `openwrt-imagebuilder`'s input in `flake.nix`. Instructions on how to do so in the aforementioned file. If after pinning to the latest commit you're still getting a `hash mismatch` error, then refer to the instructions in `~/shuurinet-nix/openwrt/image-definitions/builder-extractor/README.md`.

Don't forget to set `deploymentMode` to `true` in the `let` block of the router host's configuration.nix. Once fully deployed, disable and switch to the router VM for internet access. 
#### Notes & Quirks

Virtualisation module currently doesn't play nice with nixos-anywhere. Comment out any config related to it for the deployment. Once deployed, re-enable. 

Error in question for future debugging:

```bash
… while evaluating definitions from `/nix/store/lzml2qh553njgdalw5cbbc208vwachr6-source/nixos/modules/system/etc/etc.nix':

… while evaluating the option `environment.etc."qemu-images.json".source':

… while evaluating definitions from `/nix/store/lzml2qh553njgdalw5cbbc208vwachr6-source/nixos/modules/system/etc/etc.nix':

… while evaluating the option `environment.etc."qemu-images.json".text':

… while evaluating definitions from `/nix/store/5zpbx86wgzp957sqbd9zk3kxkpq4k1m0-source/qemu/image-manager':

(stack trace truncated; use '--show-trace' to show the full, detailed trace)

error: opening file '/private/etc/ssh/ssh_host_ed25519_key.pub': No such file or directory
```

