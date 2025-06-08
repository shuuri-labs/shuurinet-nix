{ config, lib, pkgs, ... }:
let
  mkUndervoltConfig = {
    cpu,
    gpu,
    cpuCache,
    systemAgent,
    analogIo,
  }: ''
    undervolt 0 'CPU' ${toString cpu}
    undervolt 1 'GPU' ${toString gpu}
    undervolt 2 'CPU Cache' ${toString cpuCache}
    undervolt 3 'System Agent' ${toString systemAgent}
    undervolt 4 'Analog I/O' ${toString analogIo}
  '';
in 
{
  options.intel.undervolt = {
    enable = lib.mkEnableOption "intel-undervolt";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        cpu = -140; # set to 100-125 if non-xeon
        gpu = 0;
        cpuCache = config.intel.undervolt.settings.cpu; 
        systemAgent = -40;
        analogIo = 0;
      };
    };
  };

  config = lib.mkIf config.intel.undervolt.enable {
    environment.systemPackages = with pkgs; [
      intel-undervolt
    ];

    systemd.services.intel-undervolt-config = {
      description = "Write and apply intel-undervolt config";
      before = [ "intel-undervolt.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = ''
          ${pkgs.writeShellScript "write-intel-undervolt-conf" ''
            echo "${mkUndervoltConfig config.intel.undervolt.settings}" > /etc/intel-undervolt.conf
            chmod 644 /etc/intel-undervolt.conf
            ${pkgs.intel-undervolt}/bin/intel-undervolt apply
          ''}
        '';
      };
    };
  };
}