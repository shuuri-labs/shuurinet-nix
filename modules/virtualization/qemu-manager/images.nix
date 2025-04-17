{ config, lib, pkgs, ... }:

let
  # Helper function to create conversion command based on source format
  mkConvertCommand = name: imgConfig: ''
    mkdir -p "$(dirname ${imgConfig.targetPath})"
    ${pkgs.qemu}/bin/qemu-img convert \
      -f ${imgConfig.sourceFormat} \
      -O qcow2 \
      ${imgConfig.sourcePath} \
      ${imgConfig.targetPath}
  '';

  mkResizeCommand = name: imgConfig: ''
    ${pkgs.qemu}/bin/qemu-img resize ${imgConfig.targetPath} ${toString imgConfig.size}G
  '';

  cfg = config.virtualisation.qemu.manager.images;
in {
  options.virtualisation.qemu.manager.images = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      options = {
        enable = lib.mkEnableOption "QEMU image conversion";

        sourcePath = lib.mkOption {
          type = lib.types.path;
          description = "Path to source image";
          example = "/path/to/source.raw";
        };

        sourceFormat = lib.mkOption {
          type = lib.types.enum [ "raw" "vpc" "vmdk" "vdi" "vhdx" "qcow" "qcow2" ];
          description = "Format of source image";
          example = "raw";
        };

        targetPath = lib.mkOption {
          type = lib.types.path;
          description = "Path to converted qcow2 image";
          example = "/var/lib/vms/win10.qcow2";
        };

        resize = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.positive;
          default = null;
          description = "Optional: resize the image to this size (in GB)";
          example = 20;
        };
      };
    }));
    
    default = {};
    description = "QEMU image conversion configuration";
    example = {
      "win10" = {
        enable = true;
        sourcePath = "/path/to/win10.raw";
        sourceFormat = "raw";
        targetName = "win10";
        targetDirectory = "/var/lib/vms";
        resize = 50;
      };
    };
  };

  config = lib.mkIf (cfg != {}) {
    systemd.services = lib.mapAttrs (name: imgConfig:
      lib.mkIf imgConfig.enable {
        description = "Convert ${name} to qcow2 format";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.qemu ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = 
          let
            convertCmd = mkConvertCommand name imgConfig;
            resizeCmd = if imgConfig.resize != null then mkResizeCommand name imgConfig else "";
          in
          ''
            # Only convert if target doesn't exist or source is newer
            if [ ! -f "${imgConfig.targetPath}" ] || [ "${imgConfig.sourcePath}" -nt "${imgConfig.targetPath}" ]; then
              ${convertCmd}
              ${resizeCmd}
            else
              echo "Target ${imgConfig.targetPath} exists and is up to date"
            fi
          '';
      }
    ) cfg;
  };
}