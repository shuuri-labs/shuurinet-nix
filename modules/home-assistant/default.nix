{ config, lib, inputs, pkgs, ... }:
let  
  inherit (inputs) nixvirt;
  cfg = config.homeAssistant.deploy;
in
{
  options.homeAssistant.deploy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    release = lib.mkOption {
      type = lib.types.str;
      default = "15.2";
    };

    imageName = lib.mkOption {
      type = lib.types.str;
      default = "haos_ova-${cfg.release}.qcow2";
    };

    imageURL = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/home-assistant/operating-system/releases/download/${cfg.release}/haos_ova-${cfg.release}.qcow2.xz";
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
  };

  config = lib.mkIf cfg.enable {  
    systemd.services.home-assistant-downloader = {
      description = "Download and extract Home Assistant image";
      wantedBy = [ "multi-user.target" ];

      script = ''
        set -euo pipefail

        OUTPUT_DIR="${cfg.outputDirectory}"
        VM_DIR="${cfg.vmDirectory}"
        IMAGE="${cfg.imageName}"
        IMAGE_XZ="$IMAGE.xz"

        mkdir -p "$OUTPUT_DIR"
        mkdir -p "$VM_DIR"

        # Download the image if missing
        if [ ! -f "$OUTPUT_DIR/$IMAGE_XZ" ]; then
          echo "Downloading Home Assistant image..."
          ${pkgs.curl}/bin/curl -L -o "$OUTPUT_DIR/$IMAGE_XZ" "${cfg.imageURL}"
        else
          echo "Home Assistant image already downloaded."
        fi

        # Extract the image if missing in VM dir
        if [ ! -f "$VM_DIR/$IMAGE" ]; then
          echo "Copying and extracting Home Assistant image..."
          cp "$OUTPUT_DIR/$IMAGE_XZ" "$VM_DIR/"
          ${pkgs.xz}/bin/unxz -f "$VM_DIR/$IMAGE_XZ"
        else
          echo "Home Assistant image already extracted."
        fi
      '';

      serviceConfig.Type = "oneshot";
    };

    systemd.services.refresh-libvirt-pool = {
      description = "Refresh libvirt storage pool after Home Assistant image update";
      after = [ "home-assistant-downloader.service" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        set -euo pipefail
        echo "Refreshing libvirt pool..."
        ${pkgs.libvirt}/bin/virsh pool-refresh ${cfg.virshPool}
      '';

      serviceConfig.Type = "oneshot";
    };
  };
}
