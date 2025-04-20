{ config, pkgs, lib, ... }:
let
  images = config.virtualisation.qemu.manager.images;

  makeImage = name: img:
    # Ensure that if you specify a URL, you also pinned its sha256
    # Simple built‑in assert (no message)
    assert (img.sourceUrl == null || img.sourceSha256 != null);

    let
      # If sourcePath is a derivation (like our flake package), use it directly
      sourceFile = if lib.isDerivation img.sourcePath
                  then img.sourcePath
                  else if img.sourceUrl != null then
                    pkgs.fetchurl {
                      url = img.sourceUrl;
                      sha256 = img.sourceSha256;
                    }
                  else img.sourcePath;
    in
      pkgs.stdenv.mkDerivation {
        name = "qemu-image-${name}";

        # 1) fetch (with sha256) or use local
        src = sourceFile;

        # Skip default unpack phase if we're not dealing with a compressed file
        dontUnpack = img.compressedFormat == null;

        # Explicitly set the phases we want to run
        phases = [ "unpackPhase" "buildPhase" "installPhase" ];

        # 2) unpack if compressedFormat is set
        unpackPhase = lib.optionalString (img.compressedFormat != null)
          ''
            # Get just the filename without path
            srcFile=$(basename "$src")
            
            # Copy source file to current directory
            cp "$src" "$srcFile"
            
            case "${img.compressedFormat}" in
              zip) unzip "$srcFile"        ;;
              gz)  gunzip -f "$srcFile"    ;;
              bz2) bunzip2 -f "$srcFile"   ;;
              xz)  unxz -f "$srcFile"      ;;
            esac
          '';

        # 3) convert → qcow2, then maybe resize
        buildInputs = [ pkgs.qemu pkgs.xz ];

        buildPhase = ''
          outFile=${name}.qcow2
          inFile=$(basename "$src" .${img.compressedFormat})

          if [ "${img.sourceFormat}" != "qcow2" ] || [ ! -f "$outFile" ]; then
            qemu-img convert \
              -f ${img.sourceFormat} \
              -O qcow2 \
              "$inFile" \
              "$outFile"
          fi

          ${lib.optionalString (img.resizeGB != null) ''
            qemu-img resize "$outFile" ${toString img.resizeGB}G
          ''}
        '';

        # 4) install the final qcow2
        installPhase = ''
          mkdir -p $out
          mv *.qcow2 $out/
        '';
      };

  # Build only "enabled" images into a set of derivations
  builtImages = lib.mapAttrs (name: img:
    makeImage name img
  ) (lib.filterAttrs (_: img: img.enable or false) images);
in 
{
  ##############################################################################
  # 1) Module options
  options.virtualisation.qemu.manager.images = lib.mkOption {
    type        = lib.types.attrsOf (lib.types.submodule ({
      options = {
        enable = lib.mkEnableOption "Build and convert this QEMU image";

        sourcePath = lib.mkOption {
          type        = lib.types.nullOr lib.types.path;
          default     = null;
          description = "Local path to an image file (instead of sourceUrl).";
        };

        sourceUrl = lib.mkOption {
          type        = lib.types.nullOr lib.types.str;
          default     = null;
          description = "Remote URL to fetch the image from.";
        };

        sourceSha256 = lib.mkOption {
          type        = lib.types.nullOr lib.types.str;
          default     = null;
          description = '' 
            Required if `sourceUrl` is set.  
            Pin the URL by its sha256 to avoid floating updates.
            You can get the sha256 by running `nix-prefetch-url <url>`
          '';
        };

        sourceFormat = lib.mkOption {
          type        = lib.types.enum [ "raw" "vmdk" "vdi" "vhdx" "qcow" "qcow2" ];
          default     = "raw";
          description = "Format of the source image.";
        };

        compressedFormat = lib.mkOption {
          type        = lib.types.nullOr (lib.types.enum [ "zip" "gz" "bz2" "xz" ]);
          default     = null;
          description = "Decompression type, if the source is an archive.";
        };

        resizeGB = lib.mkOption {
          type        = lib.types.nullOr lib.types.ints.positive;
          default     = null;
          description = "If set, resize the resulting qcow2 to this size in GiB.";
        };
      };
    }));
    default     = { };
    description = "Declarative download/unzip/convert of VM images to qcow2.";
  };

  options.virtualisation.qemu.manager.builtImages = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    default = builtImages;
    description = "Internal: built image derivations";
  };

  # 2) Emit /etc/qemu-images.json once any image is enabled
  config = lib.mkIf (lib.any (img: img.enable) (lib.attrValues images)) {
     environment.etc."qemu-images.json".text = builtins.toJSON (
       lib.mapAttrs (name: drv: {
         path = "${drv}//${name}.qcow2";
         format = "qcow2";  # All our converted images are qcow2
       }) builtImages
     );
   };
}


