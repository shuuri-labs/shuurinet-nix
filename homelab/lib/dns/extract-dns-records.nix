# Utility to extract DNS records from host configurations
{ lib, pkgs, inputs }:

let
  # Function to safely extract DNS records from a host configuration file
  extractDnsRecords = hostConfigPath: 
    let
      # Try to evaluate the configuration safely
      tryEvaluate = builtins.tryEval (
        let
          # Create a minimal evaluation to get just the DNS records
          evaluation = lib.evalModules {
            modules = [
              # Import the host configuration
              hostConfigPath
              
              # Import essential homelab modules
              ../homelab
              ../modules/common
              
              # Provide minimal options that might be referenced
              ({ config, lib, pkgs, ... }: {
                options = {
                  age.secrets = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    default = {};
                  };
                  
                  networking.hostName = lib.mkOption {
                    type = lib.types.str;
                    default = "unknown";
                  };
                  
                  services = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    default = {};
                  };
                  
                  users = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    default = {};
                  };
                  
                  virtualisation = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    default = {};
                  };
                  
                  systemd = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    default = {};
                  };
                  
                  environment = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    default = {};
                  };
                  
                  boot = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    default = {};
                  };
                };
                
                # Provide dummy values for commonly referenced paths
                config = {
                  age.secrets = {};
                  networking.hostName = "extracted-host";
                };
              })
            ];
            
            # Override specialArgs to provide the necessary inputs
            specialArgs = {
              inherit inputs pkgs;
            };
          };
        in
          evaluation.config.homelab.lib.dns.records or {}
      );
    in
      if tryEvaluate.success then tryEvaluate.value else {};

  # Function to extract DNS records from multiple hosts
  extractMultipleHosts = hostConfigs: 
    lib.foldl' (acc: hostConfig: acc // (extractDnsRecords hostConfig)) {} hostConfigs;

  # Safe extraction for each host (returns empty set if evaluation fails)
  safeDondozo = extractDnsRecords /home/ashley/shuurinet-nix/hosts/dondozo/configuration.nix;
  safeCastform = extractDnsRecords /home/ashley/shuurinet-nix/hosts/castform/configuration.nix;
  safeLudicolo = extractDnsRecords /home/ashley/shuurinet-nix/hosts/ludicolo/configuration.nix;
  safeTatsugiri = extractDnsRecords /home/ashley/shuurinet-nix/hosts/tatsugiri/configuration.nix;

in
{
  inherit extractDnsRecords extractMultipleHosts;
  
  # Pre-configured functions for known hosts
  dondozo = safeDondozo;
  castform = safeCastform;
  ludicolo = safeLudicolo;
  tatsugiri = safeTatsugiri;
  
  # All hosts combined
  allHosts = safeDondozo // safeCastform // safeLudicolo // safeTatsugiri;
  
  # Individual host extraction functions
  extractFromDondozo = extractDnsRecords /home/ashley/shuurinet-nix/hosts/dondozo/configuration.nix;
  extractFromCastform = extractDnsRecords /home/ashley/shuurinet-nix/hosts/castform/configuration.nix;
  extractFromLudicolo = extractDnsRecords /home/ashley/shuurinet-nix/hosts/ludicolo/configuration.nix;
  extractFromTatsugiri = extractDnsRecords /home/ashley/shuurinet-nix/hosts/tatsugiri/configuration.nix;
  
  # Debug information
  debug = {
    dondozoSuccess = (builtins.tryEval safeDondozo).success;
    castformSuccess = (builtins.tryEval safeCastform).success;
    ludicoloSuccess = (builtins.tryEval safeLudicolo).success;
    tatsugiriSuccess = (builtins.tryEval safeTatsugiri).success;
  };
} 