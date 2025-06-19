{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.lib.dashboard.glances;

  url = "http://localhost:${toString cfg.port}";

  diskWidgets = lib.listToAttrs (map (disk: {
    name = "Disk I/O ${disk.name}";
    value = {
      widget = {
        type = "glances";
        url = url;
        metric = "disk:${disk.metric}";
        chart = false;
        version = "4";
      };
    };
  }) cfg.disks);

  networkWidgets = lib.listToAttrs (map (interface: {
    name = "Network ${interface}";
    value = {
      widget = {
        type = "glances";
        url = url;
        metric = "network:${interface}";
        chart = false;
        version = "4";
      };
    };
  }) cfg.networkInterfaces);

  baseWidgets = {
    CPU = {
      widget = {
        type = "glances";
        url = url;
        metric = "cpu";
        chart = false;
        version = "4";
      };
    };

    Memory = {
      widget = {
        type = "glances";
        url = url;
        metric = "memory";
        chart = false;
        version = "4";
      };
    };

    Processes = {
      widget = {
        type = "glances";
        url = url;
        metric = "process";
        chart = false;
        version = "4";
      };
    };
  };
in
{
  options.homelab.lib.dashboard.glances = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable glances";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 61208;
      description = "Port to run glances on";
    };

    networkInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.string;
      default = [];
      description = "Network interfaces to monitor";
    };

    disks = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name for the disk";
          };
          metric = lib.mkOption {
            type = lib.types.str;
            description = "Metric name for the disk in glances (e.g. sda, nvme0n1)";
          };
        };
      });
      default = [];
      description = "Disks to monitor";
      example = [
        { name = "Boot"; metric = "sdb"; }
        { name = "Data"; metric = "nvme0n1"; }
        { name = "Editing"; metric = "nvme1n1"; }
        { name = "Rust"; metric = "sda"; }
      ];
    };

    widgets = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = baseWidgets // diskWidgets // networkWidgets;
      description = "Generated glances widgets for homepage dashboard";
    };
  };
  
  config = lib.mkIf cfg.enable {
    services.glances = {
      enable = lib.mkDefault cfg.enable;
      port = lib.mkDefault cfg.port;
    };
  };
}