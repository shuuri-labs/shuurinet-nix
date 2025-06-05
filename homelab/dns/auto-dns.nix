{ config, lib, pkgs, ... }:
let
  cfg = config.homelab;
  
  # Convert the records attribute set to a list for DNS providers
  recordsList = lib.mapAttrsToList (name: record: record) cfg.dns.records;
in
{
  config = lib.mkIf cfg.enable {
    # Convert homelab.dns.records (attribute set) to a list for DNS providers
    homelab.dns.recordsList = recordsList;
  };
} 