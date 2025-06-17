{ config, lib, ... }:

let
  inherit (lib) mkOption types;
  cfg = config.homelab.system.uefi.boot;
in
{
  options.homelab.system.uefi.boot = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable UEFI boot";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.grub.enable = true;
    # Allow GRUB to write to EFI variables
    boot.loader.efi.canTouchEfiVariables = true;
    # Specify the target for GRUB installation
    boot.loader.grub.efiSupport = true;
    boot.loader.grub.device = "nodev"; # For UEFI systems
  };
}
