{ config, lib, pkgs, ... }:
let
  cfg = config.mediaServer.services;
  vpnConfinementNamespace = config.mediaServer.vpnConfinement.namespace;
  inherit (lib) types;
in
{
  options.mediaServer.services = {
    enable = lib.mkOption {
      type = types.bool; 
      default = false; 
      description = ""; 
    };

    enableAnimeSonarr = lib.mkOption {
      type = types.bool; 
      default = false; 
      description = ""; 
    };

    downloadDir = lib.mkOption {
      type = types.str; 
      default = "/mnt/downloads"; 
      description = ""; 
    };

    transmissionAccessGroups = lib.mkOption {
      type = types.listOf types.str; 
      default = [] ; 
      description = "";
    };

    radarrSonarrAccessGroups = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "";
    };
  };

  config = lib.mkIf cfg.enable {
    # create and enable VPN confinement services
    systemd.services = {
      transmission.vpnConfinement = {
        enable = true; 
        vpnNamespace = vpnConfinementNamespace;
      };

      prowlarr.vpnConfinement = {
        enable = true; 
        vpnNamespace = vpnConfinementNamespace;
      };

      radarr.vpnConfinement = {
        enable = true; 
        vpnNamespace = vpnConfinementNamespace;
      };

      sonarr.vpnConfinement = {
        enable = true; 
        vpnNamespace = vpnConfinementNamespace;
      };

      bazarr.vpnConfinement = {
        enable = true; 
        vpnNamespace = "wg-mv";
      };
    };

    nixpkgs.config.permittedInsecurePackages = [
      "aspnetcore-runtime-6.0.36"
      "aspnetcore-runtime-wrapped-6.0.36"
      "dotnet-sdk-6.0.428"
      "dotnet-sdk-wrapped-6.0.428"
    ];

    services = {
      transmission = {
        enable = true;
        openFirewall = true;
        package = pkgs.transmission_4;
        settings = {
          download-dir = cfg.downloadDir;
          incomplete-dir-enabled = false;
          "rpc-authentication-required" = false;
          "ratio-limit-enabled" = true;
          "ratio-limit" = 2.0;
        };
      };

      prowlarr.enable = true;

      radarr = {
        enable = true; 
        openFirewall = true; 
      };

      sonarr = {
        enable = true; 
        openFirewall = true; 
      };

      bazarr = {
        enable = true;
        openFirewall = true;
      };
      
      jellyfin = {
        enable = true; 
        openFirewall = true;
      };

      jellyseerr = {
        enable = true; 
        openFirewall = true;
      };
    };

    # Add extra groups to the existing Sonarr and Radarr users
    users.users = {
      sonarr.extraGroups = cfg.radarrSonarrAccessGroups;
      radarr.extraGroups = cfg.radarrSonarrAccessGroups;
      transmission.extraGroups = cfg.transmissionAccessGroups;
    };
  };
}
