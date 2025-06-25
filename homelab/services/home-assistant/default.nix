{ config, lib, inputs, ... }:
let
  service = "home-assistant";

  homelab = config.homelab;
  cfg     = homelab.services.${service}; 

  common   = import ../common.nix { inherit lib config homelab service; };
  commonVm = import ../common-vm.nix { inherit lib config inputs service; };
in
{
  options.homelab.services.${service} = common.options // commonVm.options // {
    version = lib.mkOption {
      type = lib.types.str;
      default = "15.2";
      description = "Version of the Home Assistant OS to use";
    };
  };

  config = lib.mkMerge [
    common.config
    commonVm.config

    (lib.mkIf cfg.enable {
      virtualisation = { 
        qemu.manager.images.${service} = {
          enable = true;
          source = "https://github.com/home-assistant/operating-system/releases/download/${cfg.version}/haos_ova-${cfg.version}.qcow2.xz";
          sourceFormat = "qcow2";
          sourceSha256 = "0jbjajfnv3m37khk9446hh71g338xpnbnzxjij8v86plymxi063d";
          compressedFormat = "xz";
        };
      };

      homelab = { 
        services.${service} = {
          port = lib.mkDefault 8123;
          fqdn.topLevel = lib.mkDefault "home";
          /*
          To get reverse proxy working, add the following to home assistant's configuration.yaml:
          ```
          http:
            use_x_forwarded_for: true
            trusted_proxies:
              - <proxy_host_ip>
          ```
          ref: https://www.home-assistant.io/integrations/http/
          */
          vm = {
            baseImage = "${service}";
            memory = lib.mkDefault 3072;
            rootScsi = true;
            vncPort = lib.mkDefault 2;
          };
        };
      };
    })
  ];
}