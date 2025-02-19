{ config, lib, pkgs, ... }:

let
  cfg = config.frigate;
in
{
  options.frigate = {
    enable = lib.mkEnableOption "frigate";

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/podman/volumes/frigate/media";
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

    # Ensure the directories exist and set c
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir} 0755 ${cfg.mainUser} ${cfg.nvrMediaAccessGroup} -"
      "d ${cfg.configDir} 0755 root root -"
      "d ${cfg.configDir}/config.yaml 0777 root root -"
      "z ${cfg.mediaDir} 0755 ${cfg.mainUser} ${cfg.nvrMediaAccessGroup} -"
      "z ${cfg.configDir} 0755 root root -"
      "z ${cfg.configDir}/config.yaml 0777 root root -"
    ];

    systemd.services.podman-frigate = {
      aliases = [ "frigate.service" ];
      preStart = ''
        # Ensure config directory exists
        mkdir -p ${cfg.configDir}
        
        # Only copy config if it doesn't exist at destination
        if [ ! -f ${cfg.configDir}/config.yaml ]; then
          echo "No config file found, copying default config..."
          cp ${pkgs.writeText "frigate-config.yaml" cfg.configFile} ${cfg.configDir}/config.yaml
          # Set initial permissions
          chown root:${cfg.nvrMediaAccessGroup} ${cfg.configDir}/config.yaml
          chmod 644 ${cfg.configDir}/config.yaml
        fi
      '';
    };

    virtualisation.oci-containers = {
      containers.frigate = {
        image = "ghcr.io/blakeblackshear/frigate:stable";
        environment = {
          # FRIGATE_RTSP_PASSWORD = "changme";  # Replace with actual password
          TZ = config.time.timeZone;
        };
        volumes = [
          "${cfg.configDir}:/config"
          "${cfg.mediaDir}:/media/frigate"
        ];
        ports = [
          "8971:8971"
          "127.0.0.1:5001:5000" # Internal unauthenticated access. Expose carefully.
          "8554:8554" # RTSP feeds
          "8555:8555/tcp" # WebRTC over tcp
          "8555:8555/udp" # WebRTC over udp
        ];
        extraOptions = [
          "--device=/dev/dri/renderD128:/dev/dri/renderD128"
          "--device=/dev/dri/card0:/dev/dri/card0"
          "--shm-size=500m"
          "--tmpfs=/tmp/cache:rw,size=1000000000"
        ];
        autoStart = true;
      };
    };

    # environment.systemPackages = with pkgs; [
    #   (writeShellScriptBin "frigate-logs" ''
    #     exec ${pkgs.podman}/bin/podman logs -f frigate
    #   '')
    #   (writeShellScriptBin "frigate-status" ''
    #     echo "Container Status:"
    #     ${pkgs.podman}/bin/podman ps -f name=frigate
    #     echo -e "\nContainer Details:"
    #     ${pkgs.podman}/bin/podman inspect frigate
    #   '')
    # ];

    networking.firewall.allowedTCPPorts = [ 8971 /* 5001 */ 8554 8555 ];
    networking.firewall.allowedUDPPorts = [ 8554 8555 ];
  };
}

/* 

# Stop the container
sudo systemctl stop frigate

# Remove the container
sudo podman rm -f frigate

# Remove the container's volumes/data
sudo rm -rf /var/lib/containers/storage/volumes/frigate
sudo rm -rf /var/lib/frigate  # If this directory exists
sudo rm -rf ${hostCfgVars.storage.paths.bulkStorage}/nvr/media/*  # Be careful with this one - it will delete all recorded media

# Remove any remaining container storage
sudo podman volume rm -f frigate
sudo podman system prune -f  # This removes all unused containers, networks, and images

# Start fresh
sudo systemctl start frigate

*/