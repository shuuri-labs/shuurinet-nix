{ config, lib, pkgs, ... }:

let
  service = "frigate";
  cfg = config.services.${service};

  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
  copyConfigService = import ../../lib/utils/copy-config.nix { inherit lib pkgs; };
in
{
  options.services.${service} = common.options // {
    configFile = lib.mkOption {
      type = lib.types.str;
      description = "Content of the Frigate configuration file";
    };

    password = lib.mkOption {
      type = lib.types.str;
      description = "Password for the Frigate web UI";
      default = "changeme";
    };

    directories = {
      config = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/frigate";
      };

      recordings = lib.mkOption {
        type = lib.types.str;
        description = "Path to the media storage. Normally bulk storage root file path.";
        default = "${cfg.homelab.storage.paths.bulkStorage}/nvr/media";
      };
    };

    nvrMediaAccessGroup = lib.mkOption {
      type = lib.types.str;
      default = "nvrMediaAccess";
    };
  };

  config = lib.mkMerge [
    common.config

    (lib.mkIf cfg.enable {
      homelab.services.${service} = {
        port = lib.mkDefault 8971;
        domain.topLevel = lib.mkDefault "nvr";
      };

      users = {
        groups = {
          ${cfg.nvrMediaAccessGroup} = {
            name = cfg.nvrMediaAccessGroup;
            gid = 530;
          };
        };

        users.${config.homelab.storage.mainStorageUserName} = {
          extraGroups = [ cfg.nvrMediaAccessGroup ];
        };
      };

      systemd.services = lib.mkMerge [
        (dirUtils.createDirectoriesService {
          serviceName = service;
          directories = {
            recordingsDir = cfg.recordingsDir;
            configDir = cfg.configDir;
          };
          user = "root";
          group = "root";
          before = [ "podman-frigate.service" ];
        })

        (copyConfigService {
          serviceName = "frigate";
          src = pkgs.writeText "frigate-config.yaml" cfg.configFile;
          dest = "${cfg.directories.config}/config.yaml";
          owner = "root";
          group = "root";
          mode = "0755";
          wantedBy = [ "multi-user.target" ];
          after = [ "local-fs.target" ];
          description = "Copy Frigate config file";
        })
      ];

      # TODO: run as user (rootless)
      virtualisation.oci-containers = {
        containers.frigate = {
          image = "ghcr.io/blakeblackshear/frigate:stable";
          environment = {
            FRIGATE_RTSP_PASSWORD = cfg.password;
            TZ = config.time.timeZone;
          };
          volumes = [
            "${cfg.directories.config}:/config"
            "${cfg.directories.recordings}:/media/frigate"
          ];
          ports = [
            "127.0.0.1:${toString cfg.port}:8971"
            "127.0.0.1:5001:5000" # Internal unauthenticated access. For host-local API access only
            "127.0.0.1:8554:8554" # RTSP feeds
            "127.0.0.1:8555:8555/tcp" # WebRTC over tcp
            "127.0.0.1:8555:8555/udp" # WebRTC over udp
          ];
          extraOptions = [
            "--device=/dev/dri/renderD128:/dev/dri/renderD128"
            "--device=/dev/dri/card0:/dev/dri/card1"
            "--shm-size=400m"
            "--tmpfs=/tmp/cache:rw,size=1000000000"
          ];
          autoStart = true;
        };
      };
    })
  ];
}

# Stop the container
# sudo systemctl stop frigate

# Remove the container
# sudo podman rm -f frigate

# Enter container shell
# sudo podman exec -it frigate /bin/bash


