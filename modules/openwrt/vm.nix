{config, lib, inputs, ...}:

let
  cfg = config.openwrt.vm;

  linuxUefiVmTemplate = import ../../lib/vm-templates/nixvirt-linux-uefi-host-network.nix { inherit pkgs nixvirt; };
  inherit (inputs) nixvirt;
in
{
  options.openwrt.vm = {
    enable = lib.mkEnableOption "openwrt-vm";

    diskPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to the disk image for the VM";
      default = "/var/lib/libvirt/images/openwrt-build-1.raw";
    };

    uuid = lib.mkOption {
      type = lib.types.str;
      description = "UUID for the VM";
      default = "b2399c30-9310-434a-a511-b123e069a782";
    };

    memoryMibCount = lib.mkOption {
      type = lib.types.int;
      description = "Memory in MiB for the VM";
      default = 1024;
    };
    
    hostMainInterface = lib.mkOption {
      type = lib.types.str;
      description = "Host interface for the VM";
      default = "br0";
    };

    hostManagementInterface = lib.mkOption {
      type = lib.types.str;
      description = "Host management interface for the VM";
      default = "hostMainInterface";
    };

    nicHostDevs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description = "Host devices for the VM";
      default = [];
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirt = {
      enable = true;
      
      connections."qemu:///system" = {      
        domains = [{
          definition = nixvirt.lib.domain.writeXML (
            let
              baseTemplate = linuxUefiVmTemplate.mkCustomVmTemplate {
                name = "openwrt";
                uuid = cfg.uuid;
                memoryMibCount = cfg.memoryMibCount;
                hostInterface = cfg.hostMainInterface;
              };
            in
              baseTemplate // {
                devices = baseTemplate.devices // {
                  interface = 
                  [
                    {
                      type = "bridge";
                      source = { bridge = cfg.hostMainInterface; };
                      model = { type = "virtio"; };
                      mac = { address = "5H:UR:1N:3T:12:49"; };
                    }
                    {
                      type = "bridge";
                      source = { bridge = cfg.hostManagementInterface; };
                      model = { type = "virtio"; };
                      mac = { address = "5H:UR:1N:3T:3E:8F"; };
                    }
                  ];

                  disk = [{
                    type = "volume";
                    device = "disk";
                    driver = {
                      name = "qemu";
                      type = "raw";
                      cache = "none";
                      discard = "unmap";
                    };
                    source = {
                      pool = "default";
                      volume = cfg.diskPath;
                    };
                    target = {
                      dev = "vda";
                      bus = "virtio";
                    };
                  }];

                  hostdev = nicHostDevs;
                };
              }
          );
          active = true;
        }];
      };
    };
  };
} 