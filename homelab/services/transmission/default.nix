{ config, lib, pkgs, ... }:
let
  service = "transmission";

  homelab = config.homelab;
  system  = config.homelab.system;
  storage = config.homelab.system.storage;
  cfg     = homelab.services.${service};

  address = if homelab.lib.vpnConfinement.services.${service}.enable 
            then homelab.lib.vpnConfinement.namespace.address 
            else "127.0.0.1";

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options // {
    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = storage.directories.downloads;
      description = "Directory to store downloads in";
    };

    rpcUsername = lib.mkOption {
      type = lib.types.str;
      default = "ashley";
      description = "Username to access the ${service} web UI";
    };

    rpcPassword = lib.mkOption {
      type = lib.types.str;
      default = "transmission";
      description = "Password to access the ${service} web UI";
    };

    peerPort = lib.mkOption {
      type = lib.types.int;
      default = 56544;
      description = "Port to use for peer connections";
    };
  };

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      homelab = {
        services.${service} = {
          port = lib.mkDefault 9091;
          extraGroups = lib.mkDefault [ storage.accessGroups.downloads.name ];

          fqdn.topLevel = lib.mkDefault "trans";
        };

        lib = {
          vpnConfinement.services.${service} = {
            enable = lib.mkDefault true;
            openPorts = {
              both = [ cfg.peerPort ];
            };
          };

          dashboard.entries.${service} = {
            href = "http://${system.network.primaryBridge.address}:${toString cfg.port}";
            widget = {
              type = "transmission";
              url = "http://${address}:${toString cfg.port}";
            };
          };

          domainManagement.domains.${service}.host.backend.address = lib.mkForce address;
        };
      };
      services.${service} = {
        enable = true;
        user = cfg.user;
        group = cfg.group;
        
        package = pkgs.transmission_4;

        settings = {
          download-dir = cfg.downloadDir;
          incomplete-dir-enabled = false;

          rpc-bind-address = address;
          rpc-port = cfg.port; 
          peer-port = cfg.peerPort;

          "rpc-authentication-required" = false; # TODO enable and add pw secret
          "rpc-username" = cfg.rpcUsername;
          "rpc-password" = cfg.rpcPassword;
          rpc-whitelist-enabled = false;

          "ratio-limit-enabled" = true;
          "ratio-limit" = 2.0;
        };
      };

      users.users.${service}.extraGroups = cfg.extraGroups;
      networking.firewall.allowedTCPPorts = [ cfg.port cfg.peerPort ];
    })
  ];
}