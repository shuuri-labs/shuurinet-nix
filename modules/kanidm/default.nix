{ config, lib, pkgs, ... }:
let
  cfg = config.kanidm;

  # Build a self-signed leaf cert for auth.ldn.shuuri.net
  mkCert = domain: pkgs.runCommand "cert" { } ''
    HOME=$TMPDIR
    ${pkgs.mkcert}/bin/mkcert -install
    ${pkgs.mkcert}/bin/mkcert -cert-file ${domain}.pem -key-file ${domain}-key.pem "${domain}" "127.0.0.1"
    mkdir $out
    cp ${domain}.pem ${domain}-key.pem $out/
    cp $HOME/.local/share/mkcert/rootCA.pem $out/ca.pem
  '';

  cert = mkCert "auth.ldn.shuuri.net";
in
{
  options.kanidm = {
    enable = lib.mkEnableOption "kanidm";

    adminPasswordFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the file containing the admin password";
    };

    idmAdminPasswordFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the file containing the IDM admin password";
    };

    tls_chain = lib.mkOption {
      type = lib.types.path;
      description = "Path to the TLS chain file";
    };

    tls_key = lib.mkOption {
      type = lib.types.path;
    };
  };

  config = lib.mkIf cfg.enable {
    # Add the CA certificate to the system's trust store
    security.pki.certificateFiles = [
      "${cert}/ca.pem"
      "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];

    environment.systemPackages = [
      pkgs.kanidm_1_5
    ];

    services.kanidm = {
      package = pkgs.kanidm_1_5;

      enableServer = true;

      serverSettings = {
        tls_chain = cfg.tls_chain;
        tls_key = cfg.tls_key;
        ldapbindaddress = "127.0.0.1:636";
        domain = "auth.ldn.shuuri.net";
        origin = "https://auth.ldn.shuuri.net";
        trust_x_forward_for = true;
      };

      provision = { 
        adminPasswordFile = cfg.adminPasswordFile;
        idmAdminPasswordFile = cfg.idmAdminPasswordFile;

        persons = {
          "ashley" = {
            displayName = "Ashley";
            present = true;
            mailAddresses = [ "ashley@shuuri.net" ];
          };
        };
      };
    };
  };
}

