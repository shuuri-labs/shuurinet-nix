{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
  cfg = config.mediaServer.arrMission;

  # Common container configuration
  makeMediaContainerCommonSettings = { subnet, subnet6, wireguardAddress, downloadDir, arrMediaDir, arrMissionAddressesAndPorts, stateVersion }: {

    nixpkgs.config.permittedInsecurePackages = [
      "aspnetcore-runtime-6.0.36"
      "aspnetcore-runtime-wrapped-6.0.36"
      "dotnet-sdk-6.0.428"
      "dotnet-sdk-wrapped-6.0.428"
    ];
    
    system.stateVersion = stateVersion;

    networking = {
      defaultGateway = "${subnet}.${wireguardAddress}";
      defaultGateway6 = "${subnet6}::${wireguardAddress}";

      firewall = {
        enable = true;
        allowedTCPPorts = lib.mapAttrsToList (_: service: service.port) arrMissionAddressesAndPorts;
      };
    };

    # host.storage.paths = {
    #   downloads = "/mnt/downloads";
    #   arrMedia = "/mnt/media";
    # };
  };

  # Container bind mounts configuration
  containerBindMounts = { downloadDir, arrMediaDir }: {
    "/modules" = {
      hostPath = "/etc/nixos/modules";
      isReadOnly = true;
    };

    "/mnt/downloads" = {
      hostPath = downloadDir;
    };

    "/mnt/media" = {
      hostPath = arrMediaDir;
    };
  };
in
{
  options.mediaServer.arrMission = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable arrMission services (Sonarr, Radarr, etc.)";
    };

    enableAnimeSonarr = mkOption {
      type = types.bool;
      default = false;
      description = "Enable dedicated Sonarr instance for anime";
    };
  };
    
  config = lib.mkIf cfg.enable {
    containers.arrMission = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = config.mediaServer.container.network.hostAddress;
      localAddress = "${config.mediaServer.container.network.subnet}.${config.mediaServer.container.network.arrMissionAddress}";
      hostAddress6 = config.mediaServer.container.network.hostAddress6;
      localAddress6 = "${config.mediaServer.container.network.subnet6}::${config.mediaServer.container.network.arrMissionAddress}";

      bindMounts = containerBindMounts {
        inherit (config.mediaServer) downloadDir arrMediaDir;
      };

      config = { pkgs, ... }: let
        containerSettings = makeMediaContainerCommonSettings {
          inherit (config.mediaServer.container.network) subnet subnet6 wireguardAddress;
          inherit (config.mediaServer) downloadDir arrMediaDir;
          inherit (config.system) stateVersion;
          arrMissionAddressesAndPorts = config.mediaServer.container.network.arrMissionAddressesAndPorts;
        };
      in containerSettings // {
        imports = [ 
          ../users-groups/users.nix
          ../users-groups/accessGroups.nix
        ];

        # Add empty storage paths to prevent errors
        host.storage.paths = {};

        services = {
          transmission = {
            enable = true;
            package = pkgs.transmission_4;
            user = "transmission";
            settings = {
              download-dir = "/mnt/downloads";
              incomplete-dir-enabled = false;
              "rpc-authentication-required" = false;
              "ratio-limit-enabled" = true;
              "ratio-limit" = 2.0;
            };
          };

          prowlarr.enable = true;
          
          sonarr = {
            enable = true;
            user = "radarrSonarr";
            package = pkgs.sonarr;
          };

          radarr = {
            enable = true;
            user = "radarrSonarr";
          };

          bazarr = {
            enable = true;
            user = "bazarr";
          };
        };
      };
    };

    containers.sonarrAnime = lib.mkIf cfg.enableAnimeSonarr {
      autoStart = true;
      privateNetwork = true;
      hostAddress = config.mediaServer.container.network.hostAddress;
      localAddress = "${config.mediaServer.container.network.subnet}.${config.mediaServer.container.network.sonarrAnimeAddress}";
      hostAddress6 = config.mediaServer.container.network.hostAddress6;
      localAddress6 = "${config.mediaServer.container.network.subnet6}::${config.mediaServer.container.network.sonarrAnimeAddress}";

      bindMounts = containerBindMounts {
        inherit (config.mediaServer) downloadDir arrMediaDir;
      };

      config = { pkgs, ... }: let
        containerSettings = makeMediaContainerCommonSettings {
          inherit (config.mediaServer.container.network) subnet subnet6 wireguardAddress;
          inherit (config.mediaServer) downloadDir arrMediaDir;
          inherit (config.system) stateVersion;
          arrMissionAddressesAndPorts = config.mediaServer.container.network.arrMissionAddressesAndPorts;
        };
      in containerSettings // {
        imports = [ 
          ../users-groups/users.nix
          ../users-groups/accessGroups.nix
        ];

        # Add empty storage paths to prevent errors
        host.storage.paths = {};
        
        services.sonarr = {
          enable = true;
          user = "radarrSonarr";
          package = pkgs.sonarr;
        };
      };
    };
  };
}