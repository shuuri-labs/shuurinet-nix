{ config, lib, pkgs, mkOpenWrtConfig, ... }:

let
  # cfg = config.homelab.services.openwrt.configs;

    ## --- 1 ▪ don't check ssh/scp host keys ------------------------------
  sshNoCheck = pkgs.writeShellScriptBin "ssh" ''
    exec ${pkgs.openssh}/bin/ssh \
         -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null "$@"
  '';
  scpNoCheck = pkgs.writeShellScriptBin "scp" ''
    exec ${pkgs.openssh}/bin/scp \
         -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null "$@"
  '';

  ## --- 2 ▪ service generator --------------------------------------
  makeService = {
    name,
    drv,
    host
  }: {
    description = "Auto‑deploy ${name} when derivation changes";

    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];

    ##  wrappers go FIRST in PATH  ↓
    environment = {
      NIX_PATH = "nixpkgs=${pkgs.path}";
      PATH = lib.mkForce (lib.makeBinPath ([
        sshNoCheck
        scpNoCheck
      ] ++ [
        pkgs.coreutils
        pkgs.bash
        pkgs.findutils
        pkgs.gnugrep
        pkgs.systemd
        pkgs.util-linux
        pkgs.openssh
        pkgs.gawk
        pkgs.gnused
        pkgs.jq
        pkgs.sops
        pkgs.procps
        pkgs.iproute2
        pkgs.nettools
        pkgs.which
        pkgs.mktemp
        pkgs.less
        pkgs.logger
      ]));

      HOST = host;
    };

    restartTriggers = [ drv ];

    serviceConfig = {
      Type             = "oneshot";
      RemainAfterExit  = true;

      ExecStart = ''${pkgs.writeShellScript "deploy-${name}" ''
        #!/usr/bin/env bash
        set -euo pipefail
        set -x

        ## wait_for_ssh (max 2 mins, 1 probe per second)
        wait_for_ssh() {
          local deadline=$(( $(date +%s) + 120 ))
          while ! ssh -o BatchMode=yes -o ConnectTimeout=1 "$HOST" true 2>/dev/null; do
            (( $(date +%s) >= deadline )) && {
              echo "ERROR: $HOST did not become reachable via SSH within 2 mins" >&2
              return 1
            }
            sleep 1
          done
        }

        echo "Waiting for $HOST to accept SSH…"
        wait_for_ssh

        DEPLOY_SCRIPT="${drv}/bin/deploy-${name}"
        echo "Executing $DEPLOY_SCRIPT"
        "$DEPLOY_SCRIPT"
      ''}'';

      StandardOutput = "journal";
      StandardError  = "journal";
    };
  };
in
{
  options.homelab.services.openwrt.configs = {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "OpenWRT configuration";

        name = lib.mkOption {
          type = lib.types.str;
          description = "Name of the OpenWRT configuration file";
        };

        config = lib.mkOption {
          type = lib.types.attrs;
          description = "OpenWRT configuration";
        };

        system = lib.mkOption {
          type = lib.types.str;
          description = "System to build the configuration for";
          default = "x86_64-linux";
        };

        isRouter = lib.mkOption {
          type = lib.types.bool;
          description = "Whether this configuration is a router";
          default = false;
        };
      };
      default = {};
    });    
  };

  config = lib.mkMerge (lib.mapAttrsToList (configName: configOptions: 
    lib.mkIf configOptions.enable (
      let
        host = configOptions.config.config.openwrt.${configName}.deploy.host;

        configDrv = mkOpenWrtConfig {
          configuration = configOptions.config;
          system = configOptions.system;
        };
      in
      {
        homelab = lib.mkIf configOptions.isRouter {
          services.openwrt = {
            address = lib.mkDefault "http://${host}";
            port = lib.mkDefault 80;
          };
        };

        systemd.services."${configName}-auto-configure" = makeService {
          name = configName;
          drv = configDrv;
          host = host;
        };
      }
    )
  ) config.homelab.services.openwrt.configs);
}
