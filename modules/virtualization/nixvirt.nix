{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.virtualization.nixvirt; 
  inherit (inputs) nixvirt;
in
{
  options.virtualization.nixvirt = {
    enable = lib.mkEnableOption "nixvirt";

    baseImages.path = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vms/base-images";
    };

    pools.main = {
      uuid = lib.mkOption {
        type = lib.types.str;
        default = "8d45bdd4-74b8-47b8-b0f4-0d6b3d2f7e22";
      };

      images.path = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/vms/images";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    systemd.services.nixvirt-image-storage-setup= {
      description = "Setup VM image storage directories";
      wantedBy = [ "multi-user.target" ];
      before = [ "libvirtd.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        mkdir -p ${cfg.baseImages.path}
        chmod -R 0755 ${cfg.baseImages.path}
        chown -R root:root ${cfg.baseImages.path}

        mkdir -p ${cfg.pools.main.images.path}
        chmod -R 0755 ${cfg.pools.main.images.path}
        chown -R root:root ${cfg.pools.main.images.path}
      '';
    };

    virtualisation.libvirt = {
      enable = true;

      connections."qemu:///system" = {
        pools = [{
          definition = nixvirt.lib.pool.writeXML {
            name = "default";
            uuid = cfg.pools.main.uuid;
            type = "dir";
            target = {
              path = cfg.pools.main.images.path;
            };
          };
          active = true;
        }];
      };
    };
  };
}