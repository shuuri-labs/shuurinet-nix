{ pkgs, nixvirt, ... }:

{
  mkCustomVmTemplate = { 
    name, 
    uuid, 
    memoryMibCount ? 1024,
    vcpuCount ? 2,
    hostInterface
  }:
    let
      baseTemplate = nixvirt.lib.domain.templates.linux {
        inherit name uuid;
        memory = { count = memoryMibCount; unit = "MiB"; };
        storage_vol = null;
      };
    in
      baseTemplate // {
        cpu = baseTemplate.cpu // { 
          mode = "host-model";
          check = "partial";  # Allows migration to hosts with fewer features
        };

        vcpu = {
          count = vcpuCount;
        };

        os = baseTemplate.os // {
          loader = {
            readonly = true;
            type = "pflash";
            path = "${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd";
          };
          nvram = {
            template = "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.fd";
            path = "/var/lib/libvirt/qemu/nvram/${name}_VARS.fd";
          };
          # boot = [{ dev = "hd"; }];
        };

        devices = baseTemplate.devices // {
          interface = [{
            type = "bridge";
            source = { bridge = hostInterface; };
            model = { type = "virtio"; };
          }];

          serial = [{
            type = "pty";
          }];

          console = [{
            type = "pty";
            target = {
              type = "serial";
              port = 0;
            };
          }];

          graphics = [
            {
              type = "vnc";
              listen = { type = "address"; address = "0.0.0.0"; };
              autoport = true;
            }
            {
              type = "spice";
              listen = { type = "address"; address = "0.0.0.0"; };
              autoport = true;
              image = { compression = false; };
              gl = { enable = false; };
            }
          ];

          # Add video device
          video = {
            model = {
              type = "virtio";
              vram = 32768;
              heads = 1;
              primary = true;
            };
          };
        };
      };
}