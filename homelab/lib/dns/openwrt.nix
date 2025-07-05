{ config, lib, pkgs, ... }:

let
  dns = config.homelab.lib.dns;
  cfg = dns.openwrt;

  convertDnsRecords = records: lib.attrValues (lib.mapAttrs (name: record: {
    name = record.name;
    ip = record.content;
  }) (lib.filterAttrs (name: record: 
    record.enable && 
    record.type == "A" && 
    record.content != null
  ) records));
in 
{
  options.homelab.lib.dns.openwrt = {
    enable = lib.mkEnableOption "OpenWRT DNS records";

    records = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "List of DNS records to be added to OpenWRT";
    };
  };

  config = lib.mkIf cfg.enable {
    homelab.lib.dns.openwrt.records = convertDnsRecords dns.records;
  };
}