{ config, lib, pkgs, ... }:
let
  dns = config.homelab.lib.dns;
  cfg = dns.adguard;

  convertDnsRecords = ;
in 
{
  options.homelab.lib.dns.adguard = {
    enable = lib.mkEnableOption "AdGuard Home DNS records";

    records = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "List of DNS records to be added to AdGuard Home";
    };
  };

  config = lib.mkIf cfg.enable {
    homelab.lib.dns.adguard.records = convertDnsRecords dns.records;
  };
}