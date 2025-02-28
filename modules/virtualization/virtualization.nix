{ config, lib, pkgs, ... }:

let
  cfg = config.virtualization; 
in
{
  options.virtualization = {
    enable = lib.mkEnableOption "virtualization";

    mainUser = lib.mkOption {
      type = types.str;
      description = "Main user for virtualization";
      default = "ashley";
    };
  };

  users.users.${cfg.mainUser}.extraGroups = [ "libvirtd" ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      qemu
      libvirt
      spice-gtk
    ];

    virtualisation.libvirtd = {
      enable = true;
      onShutdown = "shutdown"; # shutdown the VMs when the host shuts down
      qemu.ovmf = {
          enable = true;  # Enable UEFI support
          packages = [ pkgs.OVMFFull.fd ]; 
      };
    };
  };
}
