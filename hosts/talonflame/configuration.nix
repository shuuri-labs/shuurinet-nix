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
      allowedTCPPorts = [ 80 443 22 ];
      allowedUDPPorts = [ 80 443 22 ];
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

  # users.users.ashley.hashedPasswordFile = config.age.secrets.castform-main-user-password.path;
  # users.users.ashley.password = "p@ssuw4d0!2334";

  # -------------------------------- SECRETS --------------------------------

  age.secrets = {
    kanidm-admin-password = {
      file = "${secretsAbsolutePath}/kanidm-admin-password.age";
      owner = "kanidm";
      group = "kanidm";
    };

    caddy-cloudflare = {
      file = "${secretsAbsolutePath}/caddy-cloudflare.env.age";
      owner = "caddy";
      group = "caddy";
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

  # -------------------------------- Caddy --------------------------------

  caddy = {
    enable = true;
    environmentFile = config.age.secrets.caddy-cloudflare.path;
    defaultSite = "cloud";

    virtualHosts = {
      # "home-manager" = {
      #   name = "talonflame";
      #   site = null;
      #   destinationPort = 8082;
      # };

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

  # -------------------------------- Netbird --------------------------------


}
