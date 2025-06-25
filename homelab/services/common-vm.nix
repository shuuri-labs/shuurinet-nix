{ config, lib, inputs, service, ... }:
let 
  cfg = config.homelab.services.${service};
  primaryBridge = config.homelab.system.network.primaryBridge;
in
{
  options = {
    vm = lib.mkOption {
      type = inputs.virtualisation.lib.types.service;
      default = {};
      description = "VM configuration for the ${service} service";
    };
  };

  config = lib.mkIf (cfg.enable) {
    homelab.services.${service}.vm = { 
      enable = lib.mkDefault true; 
      uefi = lib.mkDefault true;
      hostBridges = lib.mkDefault [ "${primaryBridge.name}" ];
    };

    virtualisation = {
      intel.enable = lib.mkDefault true;
      qemu.manager.services.${service} = cfg.vm;
    };
  };
}