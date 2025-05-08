{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.openwrt.imageBuilder;
in {
  options.openwrt.imageBuilder = {
    enable = mkEnableOption "OpenWRT VM image builder";
    
    imageDefinition = mkOption {
      type = types.str;
      example = "berlin-router";
      description = "The name of the OpenWRT image definition to build";
    };
    
    outputDirectory = mkOption {
      type = types.str;
      default = "/var/lib/libvirt/images";
      description = "Directory where the processed image will be placed";
    };
    
    outputFilename = mkOption {
      type = types.str;
      default = "openwrt.raw";
      description = "Filename for the processed image";
    };
    
    refreshPool = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to refresh the libvirt storage pool after copying the image";
    };
    
    poolName = mkOption {
      type = types.str;
      default = "default";
      description = "Name of the libvirt storage pool to refresh";
    };
    
    buildOnBoot = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to build the image on system boot";
    };
    
    buildOnActivation = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to build the image during system activation";
    };
  };

  config = mkIf cfg.enable {
    # Make sure libvirt is enabled if we're going to refresh the pool
    virtualisation.libvirtd.enable = mkIf cfg.refreshPool true;
    
    # Create the build script
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "build-openwrt-image" ''
        set -e
        
        echo "Building OpenWRT image: ${cfg.imageDefinition}..."
        
        # Create a temporary directory
        TMPDIR=$(mktemp -d)
        cd $TMPDIR
        
        # Build the image (using --impure as a workaround)
        nix build --impure ${toString ../..}#${cfg.imageDefinition}
        
        # Find the ext4-combined-efi image
        IMAGE_PATH=$(find ./result -name "*ext4-combined-efi.img.gz" | head -n 1)
        
        if [ -z "$IMAGE_PATH" ]; then
          echo "Error: Could not find ext4-combined-efi image in build output"
          exit 1
        fi
        
        echo "Found image: $IMAGE_PATH"
        
        # Decompress the image
        echo "Decompressing image..."
        gzip -cd "$IMAGE_PATH" > openwrt.raw
        
        # Copy to the output directory
        echo "Copying to ${cfg.outputDirectory}/${cfg.outputFilename}..."
        cp openwrt.raw "${cfg.outputDirectory}/${cfg.outputFilename}"
        
        # Set appropriate permissions
        chown qemu:qemu "${cfg.outputDirectory}/${cfg.outputFilename}"
        chmod 644 "${cfg.outputDirectory}/${cfg.outputFilename}"
        
        # Refresh the libvirt pool if requested
        ${if cfg.refreshPool then ''
          echo "Refreshing libvirt pool ${cfg.poolName}..."
          virsh pool-refresh ${cfg.poolName}
        '' else ""}
        
        # Clean up
        cd /
        rm -rf $TMPDIR
        
        echo "OpenWRT image build and deployment complete!"
      '')
    ];
    
    # Create activation script if requested
    system.activationScripts = mkIf cfg.buildOnActivation {
      buildOpenwrtImage = {
        deps = [ "users" "groups" ];
        text = ''
          # Ensure the output directory exists
          mkdir -p ${cfg.outputDirectory}
          
          # Run the build script
          ${pkgs.sudo}/bin/sudo ${pkgs.bash}/bin/bash -c "${pkgs.writeShellScript "build-openwrt-activation" ''
            # Only build if the image doesn't exist or if we're forcing a rebuild
            if [ ! -f "${cfg.outputDirectory}/${cfg.outputFilename}" ]; then
              echo "Building OpenWRT image during activation..."
              /run/current-system/sw/bin/build-openwrt-image
            else
              echo "OpenWRT image already exists, skipping build"
            fi
          ''}"
        '';
      };
    };
    
    # Create a systemd service for boot-time building if requested
    systemd.services.build-openwrt-image = mkIf cfg.buildOnBoot {
      description = "Build OpenWRT VM image";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "libvirtd.service" ];
      path = with pkgs; [ nix gzip findutils coreutils ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "build-openwrt-service" ''
          # Only build if the image doesn't exist or if we're forcing a rebuild
          if [ ! -f "${cfg.outputDirectory}/${cfg.outputFilename}" ]; then
            echo "Building OpenWRT image at boot..."
            /run/current-system/sw/bin/build-openwrt-image
          else
            echo "OpenWRT image already exists, skipping build"
          fi
        ''}";
      };
    };
  };
}