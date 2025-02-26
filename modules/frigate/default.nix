{ config, lib, pkgs, ... }:

let
  cfg = config.frigate;
in
{
  options.frigate = {
    enable = lib.mkEnableOption "frigate";

    host.nvrMediaStorage = lib.mkOption {
      type = lib.types.str;
      description = "Path to the host's media storage volume. Normally bulk storage root file path.";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      description = "Path to the media storage. Normally bulk storage root file path.";
      default = "${cfg.host.nvrMediaStorage}/media";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/podman/volumes/frigate/config";
    };

    nvrMediaAccessGroup = lib.mkOption {
      type = lib.types.str;
      default = "nvrMediaAccess";
    };

    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "ashley";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      description = "Content of the Frigate configuration file";
    };

    password = lib.mkOption {
      type = lib.types.str;
      description = "Password for the Frigate web UI";
      default = "changeme";
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      groups = {
        ${cfg.nvrMediaAccessGroup} = {
          name = cfg.nvrMediaAccessGroup;
          gid = 530;
        };
      };

      users.${cfg.mainUser} = {
        extraGroups = [ cfg.nvrMediaAccessGroup ];
      };
    };

    # Ensure the directories/config file exist and set permissions
    systemd.services.frigate-setup = {
      description = "Setup Frigate directories, config file and permissions";
      wantedBy = [ "multi-user.target" ];
      # Run before podman but after filesystems are mounted
      before = [ "podman-frigate.service" ];
      after = [ "local-fs.target" ];
      
      # Run once at startup
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        mkdir -p ${cfg.mediaDir}
        mkdir -p ${cfg.configDir}
        
        # Set permissions recursively
        chmod -R 0755 ${cfg.host.nvrMediaStorage}
        chmod -R 0755 ${cfg.configDir}
        
        # Set ownership recursively
        chown -R root:root ${cfg.host.nvrMediaStorage}
        chown -R root:root ${cfg.configDir}

        # Only copy config file if it doesn't exist at destination
        if [ ! -f ${cfg.configDir}/config.yaml ]; then
          echo "No config file found, copying default config..."
          cp ${pkgs.writeText "frigate-config.yaml" cfg.configFile} ${cfg.configDir}/config.yaml
          chown root:root ${cfg.configDir}/config.yaml
          chmod 755 ${cfg.configDir}/config.yaml
        fi
      '';
    };

    systemd.services."podman-frigate".requires = [ "frigate-setup.service" ];

    # TODO: run as user (rootless)
    virtualisation.oci-containers = {
      containers.frigate = {
        image = "ghcr.io/blakeblackshear/frigate:stable";
        environment = {
          FRIGATE_RTSP_PASSWORD = cfg.password;
          TZ = config.time.timeZone;
        };
        volumes = [
          "${cfg.configDir}:/config"
          "${cfg.mediaDir}:/media/frigate"
        ];
        ports = [
          "8971:8971"
          "127.0.0.1:5001:5000" # Internal unauthenticated access. For host-local API access only
          "8554:8554" # RTSP feeds
          "8555:8555/tcp" # WebRTC over tcp
          "8555:8555/udp" # WebRTC over udp
        ];
        extraOptions = [
          "--device=/dev/dri/renderD128:/dev/dri/renderD128"
          "--device=/dev/dri/card0:/dev/dri/card0"
          "--shm-size=400m"
          "--tmpfs=/tmp/cache:rw,size=1000000000"
        ];
        autoStart = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ 8971 8554 8555 ];
    networking.firewall.allowedUDPPorts = [ 8554 8555 ];
  };
}

# Stop the container
# sudo systemctl stop frigate


# Remove the container
# sudo podman rm -f frigate

# Enter container shell
# sudo podman exec -it frigate /bin/bash


