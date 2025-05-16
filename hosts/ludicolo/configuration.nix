# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, lib, inputs, ... }:

let
  hostCfgVars = config.host.vars;
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 

  hostIdentifier = "10";
  hostMainIp = "${config.homelab.networks.subnets.ldn.ipv4}.${hostIdentifier}";

  kanidmCert = (import ../../lib/utils/mkCertForDomain.nix { inherit pkgs lib; }).mkCertForDomain "kanidm" "auth.ldn.shuuri.net";
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    (import ./homepage-config.nix { inherit config hostMainIp; })
    (import ./samba-config.nix { inherit config hostMainIp; })
  ];

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host

  host.vars = {
    network = {
      hostName = "ludicolo";
      staticIpConfig.enable = true;
      bridges = [
        {
          name = "br0";
          memberInterfaces = [ "enp1s0" ];  
          subnet = config.homelab.networks.subnets.ldn;
          identifier = hostIdentifier;
          isPrimary = true;
        }
      ];
    };

    storage = {
      paths = {
        bulkStorage = "/gennai-rust";
      };
    };
  };
  
  deployment.bootstrap.gitClone.host = hostCfgVars.network.hostName;

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  # Use the Linux kernel from nixpkgs-unstable for latest realtek 8169 driver
  # boot.kernelPackages = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.linuxPackages_latest;

  time.timeZone = "Europe/London";

  # Bootloader
  host.uefi-boot.enable = true;

  users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;

  environment.systemPackages = with pkgs; [
    dig
  ];
  
  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    # System
    castform-main-user-password.file = "${secretsAbsolutePath}/castform-main-user-password.age";
    sops-key.file = "${secretsAbsolutePath}/keys/sops-key.agekey.age";
    caddy-cloudflare.file = "${secretsAbsolutePath}/caddy-cloudflare.env.age";
    # Samba Users
    ashley-samba-user-pw.file = "${secretsAbsolutePath}/samba-ashley-password.age";
    media-samba-user-pw.file = "${secretsAbsolutePath}/samba-media-password.age";
    home-assistant-backup-samba-user-pw.file = "${secretsAbsolutePath}/samba-home-assistant-backup-password.age";

    # Apps
    mullvad-wireguard-config.file = "${secretsAbsolutePath}/wg-mullvad-ludicolo.conf.age";
    ludicolo-homepage-vars.file = "${secretsAbsolutePath}/ludicolo-homepage-vars.age";
    netbird-management-url.file = "${secretsAbsolutePath}/netbird-management-url.age";
    ludicolo-netbird-master-setup-key.file = "${secretsAbsolutePath}/ludicolo-netbird-master-setup-key.age";
    grafana-admin-password = {
      file = "${secretsAbsolutePath}/grafana-admin-password.age";
      owner = "grafana";
      group = "grafana";
    };
    kanidm-admin-password = {
      file = "${secretsAbsolutePath}/kanidm-admin-password.age";
      owner = "kanidm";
      group = "kanidm";
    };
    paperless-password.file = "${secretsAbsolutePath}/paperless-password.age";
  };

  common.secrets.sopsKeyPath = "${secretsAbsolutePath}/keys/sops-key.agekey.age";

  # -------------------------------- DISK CONFIGURATION --------------------------------

  zfs = {
    pools = {
      rust = {
        name = "gennai-rust";
        autotrim = false;
      };
    
    };
    network.hostId = "b4d8f29e";
  };

  diskCare = {
    enableTrim = true;
    disksToSmartMonitor = [
      { device = "/dev/disk/by-id/ata-SAMSUNG_MZ7LN256HMJP-000H1_S2Y9NB0J629446"; } # boot drive
      { device = "/dev/disk/by-id/wwn-0x5000c500be81301d"; } # HDD 1
    ];
  };

 # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard.enable = true; # configured in ./homepage-config.nix

  monitoring = {
    enable = true;
    grafana.adminPassword = "$__file{${config.age.secrets.grafana-admin-password.path}}";
    prometheus.job_name = "ludicolo";
    loki.hostname = "ludicolo";
  };

  # -------------------------------- HARDWARE FEATURES --------------------------------

  intel.graphics.enable = true;
  powersave.enable = true; 

  # -------------------------------- FILE SERVER --------------------------------

  # Samba - configured in ./samba-config.nix
  sambaProvisioner.enable = true;

  # -------------------------------- HOSTED SERVICES --------------------------------

  # Media Server

  mediaServer.enable = true;
  mediaServer.vpnConfinement.wireguardConfigFile = config.age.secrets.mullvad-wireguard-config.path; 
  mediaServer.vpnConfinement.lanSubnet = config.homelab.networks.subnets.ldn.ipv4;
  mediaServer.vpnConfinement.lanSubnet6 = config.homelab.networks.subnets.ldn.ipv6;

  mediaServer.storage.path = hostCfgVars.storage.directories.media;
  mediaServer.storage.group = hostCfgVars.storage.accessGroups.media.name;
  mediaServer.storage.hostMainStorageUser = "ashley";

  mediaServer.services.downloadDir = hostCfgVars.storage.directories.downloads; 
  mediaServer.services.downloadDirAccessGroup = hostCfgVars.storage.accessGroups.downloads.name;
  mediaServer.services.mediaDirAccessGroup = hostCfgVars.storage.accessGroups.media.name;

  # (jellyfin metadata) ldn ipv6 tunnel (Hurricane Electric) can't connect to themoviedb.org via its
  # (default) IPv6 DNS record for some reason, so fetch IPv4 address and update hosts file to force IPv4
  systemd.services.update-themoviedb-ip = {
    description = "Update themoviedb.org IP address in hosts file";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "update-themoviedb-ip" ''
        IP=$(${pkgs.dig}/bin/dig +short themoviedb.org | head -n1)
        if [ -n "$IP" ]; then
          sed -i '/themoviedb.org/d' /etc/hosts
          echo "$IP themoviedb.org api.themoviedb.org" >> /etc/hosts
        fi
      '';
    };
  };

  systemd.timers.update-themoviedb-ip = {
    wantedBy = [ "multi-user.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1h";
    };
  };

  # -------------------------------- FRIGATE --------------------------------

  frigate = {
    enable = true;
    host.nvrMediaStorage = "${hostCfgVars.storage.paths.bulkStorage}/nvr";
    mainUser = "ashley";
    configFile = builtins.readFile ./frigate/config.yml;
  };

  # -------------------------------- Virtualisation & VMs --------------------------------

  virtualisation = {
    intel.enable = true;
  };

  # -------------------------------- VPNs & REMOTE ACCESS --------------------------------

  netbird.router = {
    enable = true;
    managementUrlPath = config.age.secrets.netbird-management-url.path;
    
    peers = {
      master = {
        enable = lib.mkForce true;
        setupKey = config.age.secrets.ludicolo-netbird-master-setup-key.path;
        hostInterface = "br0";
        hostSubnet = config.homelab.networks.subnets.ldn.ipv4;
        hostGateway = config.homelab.networks.subnets.ldn.gateway;
      };
    };
  };
  
  # -------------------------------- SECURITY --------------------------------

  kanidm = {
    enable = true;

    tls_chain = "${kanidmCert}/kanidm.pem";
    tls_key = "${kanidmCert}/kanidm-key.pem";

    domain = "auth.ldn.shuuri.net";
    origin = "https://auth.ldn.shuuri.net";

    adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
    idmAdminPasswordFile = config.age.secrets.kanidm-admin-password.path;
  };

  # Add our CA certificates to the system's 'trusted' store
  security.pki.certificateFiles = [
    "${kanidmCert}/ca.pem"
  ];

  # -------------------------------- REVERSE PROXY --------------------------------

  caddy = {
    enable = true;
    environmentFile = config.age.secrets.caddy-cloudflare.path;
    defaultSite = "ldn";

    virtualHosts = {
      "home-manager" = {
        name = "ludicolo";
        site = null;
        destinationPort = 8082;
      };

      "grafana" = {
        name = "grafana";
        destinationPort = 3000;
      };

      "frigate" = {
        name = "frigate";
        destinationAddress = "https://127.0.0.1";
        destinationPort = 8971;

        proxyExtraConfig = ''
          transport http {
            tls_insecure_skip_verify
          }
        '';
      };

      "jellyfin" = {
        name = "jellyfin";
        destinationPort = 8096;
      };

      "jellyseerr" = {
        name = "requests";
        destinationPort = 5055;
      };

      "sonarr" = {
        name = "sonarr";
        destinationPort = 8989;
      };

      "radarr" = {
        name = "radarr";
        destinationPort = 7878;
      };

      "transmission" = {
        name = "transmission";
        destinationPort = 9091;
        destinationAddress = "http://192.168.15.1";
      };

      "kanidm" = {
        name = "auth";
        destinationPort = 8443;
        destinationAddress = "https://127.0.0.1";

        proxyExtraConfig = ''
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}

          transport http {
            tls_trusted_ca_certs ${kanidmCert}/ca.pem
            tls_client_auth ${kanidmCert}/kanidm.pem ${kanidmCert}/kanidm-key.pem
          }
        '';
      };
    };
  };
}

# tls_insecure_skip_verify