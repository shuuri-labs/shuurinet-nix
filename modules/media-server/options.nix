{ config, lib, pkgs, ... }:    

let
  inherit (lib) mkOption types;
in
{
  options = {
    mediaServer = {
      container.network = {
        interfaceExternal = mkOption {
          type = types.str;
          default = "br0";
          description = "";
        };

        subnet = mkOption {
          type = types.str;
          default = "42.69.42";
          description = "";
        };

        subnet6 = mkOption {
          type = types.str;
          default = "fd74:7761:3067:ffff";
          description = "";
        };

        wireguardAddress = mkOption {
          type = types.str;
          default = "10";
          description = "";
        };

        arrMissionAddress = mkOption {
          type = types.str;
          default = "11";
          description = "";
        };

        sonarrAnimeAddress = mkOption {
          type = types.str;
          default = "12";
          description = "";
        };

        arrMissionAddressesAndPorts = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              address = mkOption {
                type = types.str;
                description = "Service address";
              };
              port = mkOption {
                type = types.port;
                description = "Service port";
              };
            };
          });
          default = {};
          description = "Address and port mappings for arr services";
        };

        hostAddress = mkOption {
          type = types.str;
          default = null;
          description = "";
        };

        hostAddress6 = mkOption {
          type = types.str;
          default = null;
          description = "";
        };
      };

      downloadDir = mkOption { # TODO: replace/default with path from config.host.storage.paths?
        type = types.str;
        default = config.host.storage.paths.downloads;
        description = "";
      };

      mediaDir = mkOption { # TODO: replace/default with path from config.host.storage.paths?
        type = types.str;
        default = config.host.storage.paths.media;
        description = "";
      };

      arrMediaDir = mkOption { # TODO: replace/default with path from config.host.storage.paths?
        type = types.str;
        default = config.host.storage.paths.arrMedia;
        description = "";
      };

      enableArrReplicationSync = mkOption {
        type = types.bool;
        default = false;
        description = "Enable SSD caching for arr media library to prevent frequent HDD spin ups.";
      };
    };
  };

  config = {
    host.user.users = {
      transmission = {
        username = "transmission";
        uid = 401;
        groups = [ config.host.accessGroups.downloads.name ];
      };
      bazarr = {
        username = "bazarr";
        uid = 402;
        groups = [];
      };
      radarrSonarr = {
        username = "radarrSonarr";
        uid = 403;
        groups = [ config.host.accessGroups.downloads.name config.host.accessGroups.media.name config.host.accessGroups.arrMedia.name ];
      };
    };

    mediaServer.container.network.arrMissionAddressesAndPorts = {
      prowlarr = {
        address = "${config.mediaServer.container.network.subnet}.${config.mediaServer.container.network.arrMissionAddress}";
        port = 9696;
      };

      transmission = {
        address = "${config.mediaServer.container.network.subnet}.${config.mediaServer.container.network.arrMissionAddress}";
        port = 9091;
      };

      sonarr = {
        address = "${config.mediaServer.container.network.subnet}.${config.mediaServer.container.network.arrMissionAddress}";
        port = 8989;
      };

      radarr = {
        address = "${config.mediaServer.container.network.subnet}.${config.mediaServer.container.network.arrMissionAddress}";
        port = 7878;
      };

      sonarrAnime = {
        address = "${config.mediaServer.container.network.subnet}.${config.mediaServer.container.network.sonarrAnimeAddress}";
        port = 8989;
      };
    };
  };
}
