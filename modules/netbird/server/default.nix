{ config, lib, pkgs, ... }:
let 
  cfg = config.netbird.server;

  oidcConfigEndpoint = "https://${cfg.authDomain}/oauth2/openid/netbird/.well-known/openid-configuration";
  dataDir = "/var/lib/netbird-mgmt"; # as seen in:
  # https://github.com/PatrickDaG/nix-config/blob/ac6a608a935495f768e29c7ab690f6abadb1eadf/config/services/netbird.nix
in
{
  options.netbird.server = {
    enable = lib.mkEnableOption "Enable netbird server";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain of the netbird server";
    };

    authDomain = lib.mkOption {
      type = lib.types.str;
      description = "Domain of the auth server";
    };

    authClientID = lib.mkOption {
      type = lib.types.str;
      description = "Client ID of the auth server";
      default = "netbird";
    };

    coturn = {
      passwordFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to the coturn password file";
      };
    };

    turn = {
      passwordFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to the turn password file";
      };
    };

    management = {
      port = lib.mkOption {
        type = lib.types.int;
        description = "Port of the netbird server";
        default = 8011;
      };

      dataStoreEncrypKeyFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to the data store encryption key file";
      };
    };

    relay = {
      authSecretFile = lib.mkOption {
        type = lib.types.str;
          description = "Path to the relay auth secret file";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    services.netbird = {

      server = {
        enable = true;

        domain = cfg.domain;

        dashboard = {
          enable = true;
          enableNginx = false;

          managementServer = lib.mkForce "https://${cfg.domain}";

          settings = {
            # Maybe replace by managementServer above, unsure
            NETBIRD_MGMT_API_ENDPOINT       = lib.mkForce "https://${cfg.domain}/api";
            NETBIRD_MGMT_GRPC_API_ENDPOINT  = lib.mkForce "https://${cfg.domain}";

            # OIDC
            AUTH_AUDIENCE = cfg.authClientID;
            AUTH_CLIENT_ID = cfg.authClientID;
            # AUTH_CLIENT_SECRET = lib.mkForce "STKCu9aeeZ/nAlA0UvYHPmAbFefUw82KMQ/sw5nukfk=";
            AUTH_AUTHORITY = "https://${cfg.authDomain}/oauth2/openid/netbird";
            # USE_AUTH0 = false;
            AUTH_SUPPORTED_SCOPES = "openid profile email offline_access api";
            AUTH_REDIRECT_URI        = "/peers";
            AUTH_SILENT_REDIRECT_URI = "/add-peers";
            NETBIRD_TOKEN_SOURCE = "idToken";
          };
        };

        # relay = {
        #   authSecretFile = cfg.relay.authSecretFile;
        #   settings.NB_EXPOSED_ADDRESS = "rels://${cfg.domain}:443";
        # };
        # ??? where is this coming from. optionis don't seem to exist. see github link below

        coturn = {
          enable = true;
          passwordFile = cfg.coturn.passwordFile;
        };

        management = {
          enable = true; 
          enableNginx = false;
          
          port = cfg.management.port;
          logLevel = "DEBUG";

          dnsDomain = "shuuri.net";
          singleAccountModeDomain = "shuuri.net";

          oidcConfigEndpoint = oidcConfigEndpoint;

          settings = {
            # Stuns = [
            #   {
            #     "Proto" = "udp";
            #     "URI" = "stun:turn.${cfg.domain}:3478";
            #     "Username" = "netbird";
            #     "Password._secret" = cfg.coturn.passwordFile;
            #   }
            # ];

            TURNConfig = {
              Turns = [
                {
                  "Proto" = "udp";
                  "URI" = "turn:turn.${cfg.domain}:3478";
                  "Username" = "netbird";
                  "Password._secret" = cfg.coturn.passwordFile;
                }
              ];

              "CredentialsTTL" = "12h";
              Secret._secret = cfg.turn.passwordFile;
              "TimeBasedCredentials" = false;
            };

            Signal = {
              Proto = "https";
              URI = "${cfg.domain}:443";
              Username = "";
              Password = null;
            };

            ReverseProxy = {
              TrustedHTTPProxies = [ ];
              TrustedHTTPProxiesCount = 0;
              TrustedPeers = [ "0.0.0.0/0" ];
            };

            Datadir = "/var/lib/netbird-mgmt/data";
            
            StoreConfig = {
              Engine = "sqlite";
            };

            HttpConfig = {
              Address = "127.0.0.1:${builtins.toString cfg.management.port}";
              IdpSignKeyRefreshEnabled = true;
              OIDCConfigEndpoint = oidcConfigEndpoint;
              # AuthAudience = cfg.authClientID;
              AuthAudience             = cfg.authClientID;
              AuthClientID             = cfg.authClientID;
              TLS = {
                Enabled = false;
              };
            };

            DataStoreEncryptionKey._secret = cfg.management.dataStoreEncrypKeyFile;

            # DeviceAuthorizationFlow = {
            #   Provider = "hosted";

            #   ProviderConfig = {
            #     ClientID = cfg.authClientID;
            #     Audience = cfg.authClientID;
            #     Domain = cfg.authDomain;
            #     TokenEndpoint = "https://${cfg.authDomain}/oauth2/token";
            #     DeviceAuthEndpoint = "${oidcConfigEndpoint}/device_authorization";
            #     Scope = "openid";
            #     UseIDToken = false;
            #   };
            # };

            PKCEAuthorizationFlow = {
              UseIDToken = true;

              ProviderConfig = {
                ClientID = cfg.authClientID;
                Audience = cfg.authClientID;
                TokenEndpoint = "https://${cfg.authDomain}/oauth2/token";
                AuthorizationEndpoint = "https://${cfg.authDomain}/ui/oauth2";
                # RedirectURLs = [
                #   "https://bird.shuuri.net/peers"
                #   "https://bird.shuuri.net/add-peers"
                # ];
              };
            };
          };
        };
      };
    };


    services.caddy = {
      logFormat = lib.mkForce "level DEBUG"; 

      virtualHosts = {
        "${cfg.domain}:443" = {
          extraConfig = ''
            # ---------- gRPC: signal ----------
              handle /signalexchange.SignalExchange/* {
                reverse_proxy 127.0.0.1:8012 {
                  transport http { versions h2c }
                }
              }

              # ---------- gRPC: management ------
              handle /management.ManagementService/* {
                reverse_proxy 127.0.0.1:8011 {
                  transport http { versions h2c }
                }
              }

              # ---------- CORS pre-flight for /api/* ----------
              @api_cors_preflight {
                path   /api/*
                method OPTIONS
              }
              handle @api_cors_preflight {
                header Access-Control-Allow-Origin  "*"
                header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
                header Access-Control-Allow-Headers "Authorization, Content-Type"
                header Access-Control-Max-Age       "86400"
                respond "" 204
              }

              @apiHead {
                  method  HEAD
                  path    /api/*
              }
              handle @apiHead {
                  reverse_proxy http://127.0.0.1:8011 {
                      method GET   # upstream sees a GET, dashboard still sends HEAD
                  }
              }


              # ---------- REST: management ------
              handle /api/* {
                header Access-Control-Allow-Origin *
                reverse_proxy http://127.0.0.1:8011
              }

              # ---------- optional reflection ---
              handle /grpc.reflection.v1alpha.ServerReflection/* {
                reverse_proxy 127.0.0.1:8011 {
                  transport http { versions h2c }
                }
              }

              # ---------- dashboard SPA ---------
              handle {
                root * ${config.services.netbird.server.dashboard.finalDrv}
                encode gzip zstd
                try_files {path} /index.html
                file_server
              }

              # ---------- headers & TLS ---------
              header {
                Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
                X-Content-Type-Options    "nosniff"
                X-Frame-Options           "DENY"
                Referrer-Policy           "strict-origin-when-cross-origin"
                -Server
              }
              tls {
                dns cloudflare {env.CF_API_KEY_TOKEN}
              }
          '';
        };
      };
    };
  };
}

# https://github.com/PatrickDaG/nix-config/blob/ac6a608a935495f768e29c7ab690f6abadb1eadf/config/services/netbird.nix#L89# https://github.com/PatrickDaG/nix-config/blob/ac6a608a935495f768e29c7ab690f6abadb1eadf/config/services/netbird.nix#L89
