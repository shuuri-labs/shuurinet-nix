{ config, lib, inputs, ... }:
let
  service = "openwrt";

  homelab = config.homelab;
  cfg     = homelab.services.${service}; 
  routerConfig = cfg.router.configuration;

  common   = import ../common.nix { inherit lib config homelab service; };
  commonVm = import ../common-vm.nix { inherit lib config inputs service; };

  routerImage = if cfg.router.imageDefinition != null then
    (import ./image/builder-extractor { inherit inputs; }).mkImageExtractor {
      name = "${service}";
      imageDefinition = (import cfg.router.imageDefinition { inherit inputs; });
      format = "squashfs-combined-efi";
    }
  else
    null;
in
{
  options.homelab.services.${service} = common.options // commonVm.options // {
    router = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the OpenWRT router";
      };

      configuration = {
        value = lib.mkOption {
          type = lib.types.attrs;
          description = "Configuration for the OpenWRT router";
          default = {};
        };

        reloadOnly = lib.mkOption {
          type = lib.types.bool;
          description = "Whether to reload the router config without rebooting";
          default = true;
        };
      };

      isVM = lib.mkOption {
        type = lib.types.bool;
        description = "Whether the router is a VM";
        default = false;
      };

      imageDefinition = lib.mkOption {
        type = lib.types.path;
        description = "Path to the image definition for the OpenWRT VM";
        default = null;
      };
      
      default = {};
    };
  };

  config = lib.mkMerge [
    common.config
    commonVm.config

    (lib.mkIf cfg.enable {
      virtualisation = { 
        qemu.manager.images.${service} = lib.mkIf (cfg.router.isVM && routerImage != null) {
          enable = true;
          source = routerImage;
          sourceFormat = "raw";
          compressedFormat = "gz";
        };
      };

      homelab = { 
        services.${service} = {
          port = lib.mkDefault 80;
          fqdn.topLevel = lib.mkDefault "router";
          address = lib.mkDefault (routerConfig.value.config.openwrt.${cfg.router.name}.deploy.host or "");

          vm = lib.mkIf (cfg.router.isVM) {
            baseImage = "${service}";
            vncPort = lib.mkDefault 1;
          };
        };

        lib = { 
          openwrt.configAutoDeploy = lib.mkIf (routerConfig.value != {}) {
            enable = lib.mkDefault true;
            configs = {
              ${cfg.router.name} = {
                enable = lib.mkDefault true;
                name = lib.mkDefault cfg.router.name;
                config = lib.mkDefault routerConfig.value;
                isRouter = false;
                deployment.reloadOnly = lib.mkDefault routerConfig.reloadOnly;
              };
            };
          };
        };
      };
    })
  ];
}