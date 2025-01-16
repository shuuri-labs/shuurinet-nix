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

    mediaDirAccessGroup = lib.mkOption {
      type = types.str;
      default = "mediaDirAccess";
      description = "";
    };

    arrMediaDirAccessGroup = lib.mkOption {
      type = types.str;
      default = "arrMediaDirAccess";
      description = "";
    };

    downloadDirAccessGroup = lib.mkOption {
      type = types.str;
      default = "downloadDirAccess";
      description = "";
    };

    mainUserName = lib.mkOption {
      type = types.str;
      default = "ashley";
    };
  };

  config = lib.mkIf cfg.enable {
    # create and enable sonnar VPN confinement service
    systemd.services = {
      transmission.vpnConfinement = {
        enable = true; 
        vpnNamespace = vpnConfinementNamespace;
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
        # openFirewall = true;
        # openRPCPort = true;
        package = pkgs.transmission_4;
        settings = {
          download-dir = cfg.downloadDir;
          incomplete-dir-enabled = false;
          rpc-bind-address = "192.168.15.1"; # address of interfaces created by VPN confinement module. arrs must point to this address, but can access via <host_address>:9091 from browser
          rpc-whitelist-enabled = false;
          "rpc-authentication-required" = false; # TODO enable and add pw secret
          "ratio-limit-enabled" = true;
          "ratio-limit" = 2.0;
        };
      };

      prowlarr = {
        enable = true;
        openFirewall = true;
      };

      radarr = {
        enable = true;
        group = cfg.mediaDirAccessGroup;
        openFirewall = true; 
      };

      sonarr = {
        enable = true; 
        group = cfg.mediaDirAccessGroup;
        openFirewall = true; 
      };

      # TODO: Implement
      # sonarr-anime = lib.mkIf enableAnimeSonarr {
      #   enable = true;
      #   package = pkgs.sonarr; # Use the same package
      #   user = "sonarr"
      #   group = cfg.mediaDirAccessGroup;
      #   stateDir = "/var/lib/sonarr-anime"; # Separate state directory
      #   openFirewall = true; # Open the firewall for the custom port

      #   # Define a custom systemd service
      #   systemd.services.sonarr-anime = {
      #     enable = true;
      #     description = "Sonarr Anime Instance";
      #     after = ["network.target"];
      #     serviceConfig = {
      #       ExecStart = "${pkgs.sonarr}/bin/Sonarr --nobrowser -data=/var/lib/sonarr-anime";
      #       Restart = "always";
      #       User = "sonarr";
      #     };
      #   };

      #   # Customize the port for the second instance
      #   nginx = {
      #     enable = true;
      #     virtualHosts."192.168.11.121:8990" = {
      #       locations."/" = {
      #         proxyPass = "http://127.0.0.1:8990";
      #       };
      #     };
      #   };
      # };

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

    # Add systemd service overrides - folders must be writable by the group, not just the user
    systemd.services.radarr.serviceConfig.UMask = "0002";
    systemd.services.sonarr.serviceConfig.UMask = "0002";

    # Add extra groups to the existing Sonarr and Radarr users
    users.users = {
      sonarr.extraGroups = [ cfg.arrMediaDirAccessGroup cfg.downloadDirAccessGroup ];
      radarr.extraGroups = [ cfg.arrMediaDirAccessGroup cfg.downloadDirAccessGroup ];
      transmission.extraGroups = [ cfg.downloadDirAccessGroup ];
    };
  };
}
