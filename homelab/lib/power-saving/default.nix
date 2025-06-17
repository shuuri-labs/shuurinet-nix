{ config, pkgs, lib, ... }:

let
  cfg = config.homelab.lib.powersave;
  inherit (lib) mkIf;
in
{
  options.homelab.lib.powersave = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false; 
      description = "Enable the powersave service"; 
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      powertop
    ];

    boot.kernelParams = [
      "pcie_aspm=force"
      "pcie_aspm.policy=powersave"
    ];

    systemd.services.powersave-boot-commands = {
      description = "Powersave Boot Commands";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          /bin/sh -c "echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor && ${pkgs.powertop}/bin/powertop --auto-tune"
        '';
        RemainAfterExit = true;
        # Optionally, set the PATH if you have more commands that rely on it
        Environment = "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/bin:/usr/sbin";
      };
      enable = true;
    };
  };
}
