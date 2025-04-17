{ config, lib, inputs, ... }:
let  
  inherit (inputs) nixvirt;

  cfg = config.openwrt.deploy;
in
{
  options.openwrt.deploy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    imageToBuild = lib.mkOption {
      type = lib.types.str;
      default = "berlin-router-img";
    };

    release = lib.mkOption {
      type = lib.types.str;
      default = "24.10.0";
    };

    imageName = lib.mkOption {
      type = lib.types.str;
      default = "openwrt-${cfg.release}-x86-64-ext4-generic-combined-efi.raw";
    };

    outputDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vm/base-images";
    };

    vmDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vm/images";
    };

    virshPool = lib.mkOption {
      type = lib.types.str;
      default = "default";
    };

    flakeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashley/shuurinet-nix";
    };
  };

  config = {
    systemd.services.openwrt-builder = {
      description = "Build OpenWrt image";
      wantedBy = [ "multi-user.target" ];
      enable = cfg.enable;
      script = ''
        OUTPUT_DIR="${cfg.outputDirectory}"
        if [ ! -f "$OUTPUT_DIR/${cfg.imageName}" ]; then
          ${pkgs.nix}/bin/nix build ${cfg.flakeDirectory}#${cfg.imageToBuild} --impure
          mkdir -p "$OUTPUT_DIR"
          cp -f result/* "$OUTPUT_DIR/"
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };


    systemd.services.copy-and-refresh-openwrt-image = {
      description = "Copy and refresh OpenWRT image";
      wantedBy = [ "multi-user.target" ];
      enable = cfg.enable;

      script = ''
        set -euo pipefail

        IMAGE_NAME="${cfg.imageName}"
        OUTPUT="${cfg.outputDirectory}/$IMAGE_NAME"
        DEST="${cfg.vmDirectory}/$IMAGE_NAME"

        if [ ! -f "$DEST" ]; then
          echo "Copying OpenWRT image..."
          cp -f "$OUTPUT" "$DEST"
        fi

        echo "Refreshing libvirt pool..."
        virsh pool-refresh ${cfg.virshPool}
      '';

      serviceConfig.Type = "oneshot";
    };
  };
}


