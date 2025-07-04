{ config, lib, inputs, ... }:
let
  service = "openwrt";

  homelab = config.homelab;
  cfg     = homelab.services.${service}; 

  common   = import ../common.nix { inherit lib config homelab service; };
  commonVm = import ../common-vm.nix { inherit lib config inputs service; };

  openwrtImage = (import ./image/builder-extractor { inherit inputs; }).mkImageExtractor {
    name = "${service}";
    imageDerivation = (import cfg.imageDefinition { inherit inputs; });
    format = cfg.imageFormat;
  };
in
{
  imports = [
    ./config
  ];

  options.homelab.services.${service} = common.options // commonVm.options // { 
    imageDefinition = lib.mkOption {
      type = lib.types.path;
      description = "Path to the image definition for the OpenWRT VM";
    };

    imageFormat = lib.mkOption {
      type = lib.types.str;
      description = "Format of the OpenWRT image";
      default = "squashfs-combined-efi";
    };
  };

  config = lib.mkMerge [
    common.config
    commonVm.config

    (lib.mkIf cfg.enable {
      virtualisation = { 
        qemu.manager.images.${service} = {
          enable = true;
          source = openwrtImage;
          sourceFormat = "raw";
          compressedFormat = "gz";
        };
      };

      homelab = { 
        services.${service} = {
          fqdn.topLevel = lib.mkDefault "router";

          vm = {
            baseImage = "${service}";
            vncPort = lib.mkDefault 1;
          };
        };
      };
    })
  ];
}