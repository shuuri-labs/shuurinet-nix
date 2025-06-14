{ config, lib, pkgs, ... }:

let
  service = "frigate";
  cfg = config.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.services.${service} = common.options // {
    password = lib.mkOption {
      type = lib.types.str;
      description = "Password for the Frigate web UI";
      default = "changeme"; # TODO: read from (secrets) file
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the Frigate configuration file";
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

    intelAcceleration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Intel GPU acceleration";
      };

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "/dev/dri/renderD128" "/dev/dri/card1" ];
        description = "List of devices to use for Intel GPU acceleration";
      };

      groups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "video" "render" ];
        description = "List of groups to add the Frigate user to for GPU access";
      };
    };
  };

  config = lib.mkMerge [
    common.config

    (lib.mkIf cfg.enable {
      # -- Override default service options

      homelab.services.${service} = {
        port = lib.mkDefault 8971;
        domain.topLevel = lib.mkDefault "nvr";
      };

      # -- Create the ${service} user and group

      users = {
        "${cfg.user}" = {
          isSystemUser = true;
          uid = 580;
          group = cfg.group;
          extraGroups = if cfg.intelAcceleration.enable then cfg.intelAcceleration.groups else [];
        };
        
        groups = {
          ${cfg.group} = {
            name = cfg.group;
            gid = 580;
          };
        };

        users.${config.homelab.storage.mainStorageUserName} = {
          extraGroups = [ cfg.group ];
        };
      };

      # -- Create the directories

      systemd.services = dirUtils.createDirectoriesService {
        serviceName = service;
        directories = {
          recordingsDir = cfg.directories.recordings;
          configDir = cfg.directories.config;
        };
        user = cfg.user;
        group = cfg.group;
        before = [ "podman-frigate.service" ];
      };

      # -- Bind mount the config file

      fileSystems."${cfg.directories.config}/config.yaml" = {
        device = cfg.configFile;
        fsType = "none";
        options = [ "bind" ];
        depends = [ "/" ];
      };

      # Set permissions on the config file (user and group r/w)
      systemd.tmpfiles.rules = [
        "Z ${cfg.configFile} 0660 ${cfg.user} ${cfg.group} - -"
      ];

      # -- Create the container
      virtualisation.oci-containers = {
        containers.frigate = {
          user = cfg.user;

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
            "--shm-size=400m"
            "--tmpfs=/tmp/cache:rw,size=1000000000"
          ] ++ lib.optionals cfg.intelAcceleration.enable [
            "--device=${toString cfg.intelAcceleration.devices}"
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


