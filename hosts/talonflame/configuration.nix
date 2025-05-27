# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, inputs, lib, ... }:

let
  secretsAbsolutePath = "/home/ashley/shuurinet-nix/secrets"; 
  hostName = "talonflame";

  kanidmCert = (import ../../lib/utils/mkCertForDomain.nix { inherit pkgs lib; }).mkCertForDomain "kanidm" "auth.cloud.shuuri.net";
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  # -------------------------------- HOST VARIABLES --------------------------------
  # See /options-host

  boot.kernelParams = ["net.ifnames=0"]; # reliable interface naming
      
  networking = {
    hostName = hostName;
    interfaces.eth0.useDHCP = true;
    
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 33073 10000 33080 ];
      allowedUDPPorts = [ 3478 ];
      allowedUDPPortRanges = [ { from = 49152; to = 65535; } ];
    };
  };

  deployment.bootstrap.gitClone.host = hostName;

  # -------------------------------- HARDENING --------------------------------

  services.openssh.settings.PasswordAuthentication = false;
  services.fail2ban.enable = true;

  # -------------------------------- SYSTEM CONFIGURATION --------------------------------

  swapDevices = [{
    device = "/swapfile";
    size = 4 * 1024; # 4GB
  }];

  time.timeZone = "Europe/Helsinki";

  # Bootloader
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # environment.systemPackages = with pkgs; [
  #   caddy
  # ];

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  # users.users.ashley.password = "p@ssuw4d0!2334";

  # -------------------------------- SECRETS --------------------------------

  # users.groups = {
  #   oauth2-secrets = {
  #     name = "oauth2-secrets-access";
  #     gid = 506;
  #   };
  # };

  # users.users = {
  #   kanidm.extraGroups = [ "oauth2-secrets-access" ];
  #   turnserver.extraGroups = [ "oauth2-secrets-access" ];
  # };

  age.secrets = {
    caddy-cloudflare = {
      file = "${secretsAbsolutePath}/caddy-cloudflare.env.age";
      owner = "caddy";
      group = "caddy";
    };

    kanidm-admin-password = {
      file = "${secretsAbsolutePath}/kanidm-admin-password.age";
      owner = "kanidm";
      group = "kanidm";
    };

    kanidm-netbird-client-secret = {
      file = "${secretsAbsolutePath}/kanidm-netbird-client-secret.age";
      owner = "kanidm";
      group = "kanidm";
      # mode = "0640";
    };

    netbird-coturn-password = {
      file = "${secretsAbsolutePath}/netbird-coturn-password.age";
      owner = "turnserver";
      group = "turnserver";
    };

    netbird-turn-password = {
      file = "${secretsAbsolutePath}/netbird-turn-password.age";
      owner = "turnserver";
      group = "turnserver";
    };
    
    netbird-mgmt-data-store-encryp-key = {
      file = "${secretsAbsolutePath}/netbird-mgmt-data-store-encryp-key.age";
      owner = "turnserver";
      group = "turnserver";
    }; 
  };

  # -------------------------------- Caddy --------------------------------

  caddy = {
    enable = true;
    environmentFile = config.age.secrets.caddy-cloudflare.path;
    defaultSite = "cloud";

    virtualHosts = {
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

  # -------------------------------- MONITORING & DASHBOARD --------------------------------

  homepage-dashboard = {
    enable = true; # configured in ./homepage-config.nix
    openFirewall = false;
  };

  # -------------------------------- Kanidm --------------------------------

  kanidm = {
    enable = true;

    tls_chain = "${kanidmCert}/kanidm.pem";
    tls_key = "${kanidmCert}/kanidm-key.pem";
    domain = "auth.cloud.shuuri.net";
    origin = "https://auth.cloud.shuuri.net";

    adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
    idmAdminPasswordFile = config.age.secrets.kanidm-admin-password.path;
  };

  # Add our CA certificates to the system's 'trusted' store
  security.pki.certificateFiles = [
    "${kanidmCert}/ca.pem"
  ];

  services.kanidm.provision = {
    groups = {
      "netbird-access" = {
        present = true;
        members = [ "ashley" ];
      };
    };

    systems.oauth2 = {
      netbird = {
        displayName = "Netbird";
        present = true;
        public = true;
        enableLocalhostRedirects = true;

        # basicSecretFile = config.age.secrets.kanidm-netbird-client-secret.path;

        originUrl = [
          "https://bird.shuuri.net/peers"
          "https://bird.shuuri.net/add-peers"
          "http://localhost:53000"
        ];

        originLanding = "https://bird.shuuri.net";
        # enableLocalhostRedirects = true;

        scopeMaps = {
          netbird-access = [ 
            "openid"
            "email"
            "profile"
            "offline_access"
            "api"
          ];
        };
      };
    };
  };

  # -------------------------------- Netbird --------------------------------

  netbird.server = {
    enable = true;

    domain = "bird.shuuri.net";
    authDomain = "auth.cloud.shuuri.net";

    coturn = {
      passwordFile = config.age.secrets.netbird-coturn-password.path;
    };

    turn = {
      passwordFile = config.age.secrets.netbird-turn-password.path;
    };

    management = {
      dataStoreEncrypKeyFile = config.age.secrets.netbird-mgmt-data-store-encryp-key.path;
    };

    # relay = {
    #   authSecretFile = config.age.secrets.netbird-relay-auth-secret.path;
    # }
  };
}
