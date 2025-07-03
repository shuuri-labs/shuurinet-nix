{ config, lib, pkgs, mkOpenWrtConfig, ... }:

let
  cfg = config.homelab.services.openwrt.configs;
  # dnsRecords = config.homelab.lib.dns.openwrt.records;
  # staticLeases = config.homelab.system.network.staticLeases; 
in
{
  options.homelab.services.openwrt.configs = {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "OpenWRT configuration";

        name = lib.mkOption {
          type = lib.types.str;
          description = "Name of the OpenWRT configuration file";
        };

        config = lib.mkOption {
          type = lib.types.attrs;
          description = "OpenWRT configuration";
        };

        system = lib.mkOption {
          type = lib.types.str;
          description = "System to build the configuration for";
          default = "x86_64-linux";
        };

        isRouter = lib.mkOption {
          type = lib.types.bool;
          description = "Whether this configuration is a router";
          default = false;
        };
      };
    });    
  };

  config = lib.mkMerge (lib.mapAttrsToList (configName: configOptions: 
    lib.mkIf configOptions.enable {
      homelab = lib.mkIf configOptions.isRouter {
        services.openwrt = {
          address = lib.mkDefault "http://${configOptions.config.openwrt.${configName}.deploy.host}";
          port = lib.mkDefault 80;
        };
      };

      # config = import (builtins.path { path = ./.; name = "source"; } + "/${configOptions.configFile}") { inherit lib dnsRecords staticLeases; };
      # do above elsewhere 

      configDrv = mkOpenWrtConfig {
        configuration = configOptions.config;
        system = configOptions.system;
      };

      systemd.services."${configName}-auto-configure" = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.coreutils}/bin/true";
        };
      };
    }
  ) cfg);
}
