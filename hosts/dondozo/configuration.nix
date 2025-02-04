# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

let
  vars = {
    network = {
      hostName = "dondozo";
      interfaces = [ "enp2s0f1np1" "eno1"];
      bridge = "br0";
      unmanagedInterfaces = vars.network.interfaces ++ [ vars.network.bridge "eno2" ];
      
      subnet = config.homelab.networks.subnets.bln;

      hostAddress = "${vars.network.subnet.ipv4}.10";
      hostAddress6 = "${vars.network.subnet.ipv6}::10";
    };

    zfs = {
      network.hostId = "45072e28"; 

      pools = {
        rust = {
          name = "shuurinet-rust";
          autotrim = false;
        };
        nvmeData = {
          name = "shuurinet-nvme-data";
          autotrim = true;
        };
        nvmeEditing = {
          name = "shuurinet-nvme-editing";
          autotrim = true;
        };
      };
    };

    paths = {
      bulkStorage = "/shuurinet-rust";
      fastStorage = "/shuurinet-nvme-data";
      editingStorage = "/shuurinet-nvme-editing";
    };

    # disksToSpindown = [ "ata-ST16000NM000D-3PC101_ZVTAVSGR" "ata-ST16000NM000D-3PC101_ZVTBH31T" ];
  };

  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  time.timeZone = "Europe/Berlin";

  # Bootloader
  host.uefi-boot.enable = true;

  # Networking
  host.staticIpNetworkConfig = {
    networkConfig = vars.network;
  };

  age.secrets = {
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad.conf.age";
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
    dondozo-homepage-vars.file = "${secretsAbsolutePath}/dondozo-homepage-vars.age";
    
    grafana-admin-password = {
      file = "${secretsAbsolutePath}/grafana-admin-password.age";
      owner = "grafana";
      group = "root";
      mode = "440";
    };

    paperless-password.file = "${secretsAbsolutePath}/paperless-password.age";
  };

  # set a unique main user pw (main user created in common module)
  users.users.ashley = {
    hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  };

  # import ZFS pools
  host.zfs.pools = vars.zfs.pools;
  host.zfs.network.hostId = vars.zfs.network.hostId;

  # Host paths
  host.storage.paths = {
    media = "${vars.paths.bulkStorage}/media";
    downloads = "${vars.paths.fastStorage}/downloads";
    documents = "${vars.paths.fastStorage}/documents";
    backups = "${vars.paths.fastStorage}/backups";
  };

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      {
        device = "/dev/disk/by-id/ata-CT1000MX500SSD1_2410E89DFB65"; # boot drive
      }
      {
        device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N569313409716"; # nvme 1
      }
      {
        device = "/dev/disk/by-id/nvme-SHPP41-2000GM_ADC8N56931450976D"; # nvme 2
      }
      {
        device = "/dev/disk/by-id/ata-ST16000NM000D-3PC101_ZVTAVSGR"; # HDD 1
      }
      {
        device = "/dev/disk/by-id/ata-ST16000NM000D-3PC101_ZVTBH31T"; # HDD 2
      }
    ];
  };

  # hddSpindown.disks = vars.disksToSpindown;
  intelGraphics.enable = true;
  powersave.enable = true; 
  virtualization.intel.enable = true;

  # Media Server
  mediaServer.enable = true;
  mediaServer.vpnConfinement.wireguardConfigFile = config.age.secrets.mullvad-wireguard-config.path; 
  mediaServer.vpnConfinement.lanSubnet = vars.network.subnet.ipv4;
  mediaServer.vpnConfinement.lanSubnet6 = vars.network.subnet.ipv6;

  mediaServer.mediaDir = config.host.storage.paths.media;
  mediaServer.mediaGroup = config.host.storage.accessGroups.media.name;
  mediaServer.hostMainStorageUser = "ashley";

  mediaServer.services.downloadDir = config.host.storage.paths.downloads; 
  mediaServer.services.downloadDirAccessGroup = config.host.storage.accessGroups.downloads.name;
  mediaServer.services.mediaDirAccessGroup = config.host.storage.accessGroups.media.name;

  # Samba
  sambaProvisioner.enable = true;
  sambaProvisioner.hostName = vars.network.hostName;
  sambaProvisioner.hostIp = "${vars.network.hostAddress}/32";
  sambaProvisioner.users = [
    { name = "ashley"; 
      passwordFile = config.age.secrets.ashley-samba-user-pw.path; 
    }
    { 
      name = "media"; 
      passwordFile = config.age.secrets.media-samba-user-pw.path; 
      createHostUser = true; # samba needs a user to exist for the samba users to be created
      extraGroups = [ config.host.storage.accessGroups.media.name ]; 
    } 
  ];

  services.samba.settings = {
    shuurinet-rust = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = vars.paths.bulkStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    shuurinet-data = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = vars.paths.fastStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    shuurinet-editing = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = vars.paths.editingStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    media = {
      browseable = "yes";
      comment = "${vars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = "${vars.paths.bulkStorage}/media";
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley media"; 
    };
  };

  services.homepage-dashboard = {
    environmentFile = config.age.secrets.dondozo-homepage-vars.path;
    settings = {
      title = "dondozo dashboard";
      layout = [ 
        {
          Monitoring = { style = "row"; columns = 2; };
        }
        {
          Media = { style = "row"; columns = 2; };
        }
        {
          Downloads = { style = "row"; columns = 1; };
        }
        {
          Documents = { style = "row"; columns = 1; };
        }
      ];
      statusStyle = "dot";
    };
    widgets = [
      {
        resources = {
          cpu = true;
          disk = [ "/" vars.paths.bulkStorage vars.paths.fastStorage vars.paths.editingStorage ];
          memory = true;
          units = "metric";
          uptime = true;
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
    ];
    services = [
      {
        Media = [
          {
            Jellyfin = {
              icon = "jellyfin.png";
              href = "http://${vars.network.hostAddress}:8096";
              siteMonitor = "http://${vars.network.hostAddress}:8096";
              description = "Media Server";
              widget = {
                type = "jellyfin";
                url = "http://${vars.network.hostAddress}:8096";
                key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";
              };
            };
          }
          {
            Jellyseerr = {
              icon = "jellyseerr.png";
              href = "http://${vars.network.hostAddress}:5055";
              siteMonitor = "http://${vars.network.hostAddress}:5055";
              description = "Media Requests";
              widget = {
                type = "jellyseerr";
                url = "http://${vars.network.hostAddress}:5055";
                key = "{{HOMEPAGE_VAR_JELLYSEERR_API_KEY}}";
              };
            };
          }
          {
            sonarr = {
              icon = "sonarr.png";
              href = "http://${vars.network.hostAddress}:8989";
              description = "Media Management";
              siteMonitor = "http://${vars.network.hostAddress}:8989";
              widget = {
                type = "sonarr";
                url = "http://${vars.network.hostAddress}:8989";
                key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
              };
            };
          }
          {
            radarr = {
              icon = "radarr.png";
              href = "http://${vars.network.hostAddress}:7878";
              description = "Media Management";
              siteMonitor = "http://${vars.network.hostAddress}:7878";
              widget = {
                type = "radarr";
                url = "http://${vars.network.hostAddress}:7878";
                key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
              };
            };
          }
        ];
      }
      {
        Downloads = [
          {
            Transmission = {
              icon = "transmission.png";
              href = "http://192.168.11.10:9091";
              siteMonitor = "http://192.168.15.1:9091";
              widget = {
                type = "transmission";
                url = "http://192.168.15.1:9091";
              };
            };
          }
        ];
      }
      {
        Monitoring = [
          {
            "Power Usage" = {
              icon = "home-assistant.png";
              href = "http://10.10.33.231";
              siteMonitor = "http://192.168.11.127:8123";
              widget = {
                type = "homeassistant";
                url = "http://192.168.11.127:8123";
                key = "{{HOMEPAGE_VAR_HOMEASSISTANT_API_KEY}}";
                custom = [
                  {
                    state = "sensor.server_plug_switch_0_power";
                    label = "Server Plug";
                  }
                ];
              };
            };
          }
          {
            Grafana = {
              icon = "grafana.png";
              href = "http://${vars.network.hostAddress}:${toString config.monitoring.grafana.port}";
              siteMonitor = "http://${vars.network.hostAddress}:${toString config.monitoring.grafana.port}";
              widget = {
                type = "grafana";
                url = "http://${vars.network.hostAddress}:${toString config.monitoring.grafana.port}";
                username = "admin";
                # password = "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}"; # TODO: fix; don't forget to change environment variable
              };
            };
          }
        ];
      }
      {
        Documents = [
          {
            Paperless = {
              icon = "paperless.png";
              href = "http://${vars.network.hostAddress}:28981";
              siteMonitor = "http://${vars.network.hostAddress}:28981";
              description = "Documents";
              widget = {
                type = "paperlessngx";
                url = "http://${vars.network.hostAddress}:28981";
                key = "{{HOMEPAGE_VAR_PAPERLESS_API_KEY}}"; 
              };
            };
          }
        ];
      }
    ];
  };

  monitoring = {
    enable = true;
    grafana.adminPassword = "$__file{${config.age.secrets.grafana-admin-password.path}}";
    prometheus.job_name = "dondozo";
    loki.hostname = "dondozo";
  };

  paperless-ngx = {
    enable = true;
    passwordFile = config.age.secrets.paperless-password.path;
    documentsDir = config.host.storage.paths.documents;
    documentsAccessGroup = config.host.storage.accessGroups.documents.name;
    hostMainStorageUser = "ashley";
  };
}