{ config, lib, ... }:
{
  options = {
    imageToBuild = lib.mkOption {
      type = lib.types.str;
      default = "berlin-router";
    };

    imageName = lib.mkOption {
      type = lib.types.str;
      default = "openwrt-24.10.0-x86-64-generic.raw";
    };

    flakeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/ashley/shuurinet-nix";
    };

    outputDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vms/base-images";
    };

    vmDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vms/images";
    };
  };

  config = {
    systemd.services.openwrt-builder = {
      description = "Build OpenWrt image";
      wantedBy = [ "multi-user.target" ];
      enable = true;
      script = ''
        cd /etc/nixos
        OUTPUT_DIR="/var/lib/openwrt-images"
        if [ ! -f "$OUTPUT_DIR/${config.imageName}" ]; then
          ${pkgs.nix}/bin/nix build .#${config.imageToBuild} --impure 
          mkdir -p "$OUTPUT_DIR"
          cp -f result/* "$OUTPUT_DIR/"
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };


    systemd.services.copy-openwrt-image = {
      description = "Build OpenWrt image";
      wantedBy = [ "multi-user.target" ];
      enable = true;
      script = ''
        if [ ! -f "${config.vmDirectory}/${config.imageName}" ]; then
          cp -f ${config.outputDirectory}/${config.imageName} ${config.vmDirectory}/${config.imageName}
          virsh      
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };
  };
}


