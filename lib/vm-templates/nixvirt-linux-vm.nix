{ config, lib, pkgs, ... }:

let
  base = {
    name,
    uuid,
    cpuMode ? "host-passthrough",
    vcpuCount ? 2,
    memoryCountMib ? 1024,
    machineType ? "q35",
    enableUEFI ? true,
    networkInterfaces ? "br0"
  }: {
    inherit name uuid;

    vcpu = { count = vcpuCount; };
    cpu = { mode = cpuMode; };
    memory = { count = memoryCountMib; unit = "MiB"; };

    os = {
      type = "hvm";
      arch = "x86_64";
      boot = [{ dev = "cdrom"; } { dev = "hd"; }];
      machine = machineType;

      loader = mkIf enableUEFI {
        readonly = true;
        type = "pflash";
        path = "${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd";
      };

      nvram = mkIf enableUEFI {
        template = "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.fd";
        path = "/var/lib/libvirt/qemu/nvram/${name}_VARS.fd";
      };

      boot = mkIf enableUEFI [{ dev = "hd"; }];
    };

    clock = {
      offset = "utc";
      timer =
        [
          { name = "rtc"; tickpolicy = "catchup"; }
          { name = "pit"; tickpolicy = "delay"; }
          { name = "hpet"; present = false; }
        ];
    };

    features = {
      acpi = { };
      apic = { };
    };

    devices = {
      emulator = "${packages.qemu}/bin/qemu-system-x86_64";

      serial = [{
        type = "pty";
      }];

      console = [{
        type = "pty";
        target = {
          type = "serial";
          port = 0;
        }
      }];

      channel = [{
        type = "spicevmc";
        target = { type = "virtio"; name = "com.redhat.spice.0"; };
      }];

      graphics = [
        {
          type = "vnc";
          listen = { type = "address"; address = "127.0.0.1"; };
          port = 5901;
          attrs = {
            passwd = "changeme";
          };
        }
        {
          type = "spice";
          listen = { type = "address"; address = "127.0.0.1"; };
          autoport = true;
          image = { compression = false; };
          gl = { enable = false; };
        }
      ];

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
in
{
  inherit base;
}
    