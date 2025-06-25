{ config, lib, inputs, ... }:
let
  service = "openwrt";

  homelab = config.homelab;
  cfg     = homelab.services.${service}; 

  common   = import ../common.nix { inherit lib config homelab service; };
  commonVm = import ../common-vm.nix { inherit lib config inputs service; };

  openwrtImage = (import ./img-builder-extractor { inherit inputs; }).mkImageExtractor {
    name = "${service}";
    imageDerivation = (import cfg.imageDefinition { inherit inputs; });
    format = "squashfs-combined-efi";
  };
in
{
  options.homelab.services.${service} = common.options // commonVm.options // { 
    imageDefinition = lib.mkOption {
      type = lib.types.path;
      description = "Path to the image definition for the OpenWRT VM";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to the config file for the OpenWRT VM";
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
          address = lib.mkDefault "http://192.168.11.51"; # TODO: get from openwrt config
          port = lib.mkDefault 80;

          fqdn.topLevel = lib.mkDefault "router";

          vm = {
            baseImage = "${service}";
            vncPort = 1;
          };
        };
      };
    })
  ];
}