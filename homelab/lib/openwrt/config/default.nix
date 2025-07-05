{ config, lib, pkgs, mkOpenWrtConfig, ... }:

let
  cfg = config.homelab.lib.openwrt.configAutoDeploy;
  
  # Import our custom types
  types = import ./types.nix { inherit lib; };

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
    host,
    reloadOnly ? false
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
        DEPLOY_ARGS=""
        
        ${lib.optionalString reloadOnly ''
        DEPLOY_ARGS="$DEPLOY_ARGS --reload"
        ''}
        
        echo "Executing $DEPLOY_SCRIPT$DEPLOY_ARGS"
        $DEPLOY_SCRIPT $DEPLOY_ARGS
      ''}'';

      StandardOutput = "journal";
      StandardError  = "journal";
    };
  };
in
{
  options.homelab.lib.openwrt.configAutoDeploy = {
    enable = lib.mkEnableOption "OpenWRT configuration auto-deployment";

    configs = lib.mkOption {
      type = lib.types.attrsOf types.configDefinitionType;  
      default = {};
      description = "Set of OpenWRT configurations to deploy";
    };
  };

  # to run config deployment service manually, run `systemctl start <config.name>`
  config = lib.mkIf cfg.enable {
    systemd.services = lib.mapAttrs (configName: configOptions: 
      let
        host = configOptions.config.config.openwrt.${configName}.deploy.host;

        configDrv = mkOpenWrtConfig {
          configuration = configOptions.config;
          system = configOptions.system;
        };
      in
      makeService {
        name = configName;
        drv = configDrv;
        host = host;
        reloadOnly = configOptions.deployment.reloadOnly;
      }
    ) (lib.filterAttrs (name: configOptions: configOptions.enable) cfg.configs);
  };
}
