{config, lib, ...}:

let
  inherit (lib) mkOption types;

  cfg = config.host.vars.network.config;
in
{
  options.host.vars.network.config = {
    hostName = mkOption {
      type = types.str;
      description = "Hostname for this machine";
    };
  };

  config = {
    networking = {
      hostName = cfg.hostName;
      enableIPv6 = true;
      
      networkmanager = {
        enable = true;
      };
    };
  };
}
