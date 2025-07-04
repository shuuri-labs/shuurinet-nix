{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.openwrt.config-auto-deploy;

  ## --- 1 ▪ don't check ssh/scp host keys ------------------------------
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

  ## --- 2 ▪ service generator --------------------------------------
  makeService = {
    name,
    drv,
    serviceName ? null,
    host
  }: {
    description = "Auto‑deploy ${name} when derivation changes";

    after    = [ "network-online.target" ] ++ (if serviceName != null then [ "${serviceName}.service" ] else []);
    wants    = [ "network-online.target" ] ++ (if serviceName != null then [ "${serviceName}.service" ] else []);

    ##  wrappers go FIRST in PATH  ↓
    environment = {
      NIX_PATH = "nixpkgs=${pkgs.path}";
      PATH = mkForce (lib.makeBinPath ([
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

      SOPS_AGE_KEY_FILE = mkIf (cfg.sopsAgeKeyFile != null) cfg.sopsAgeKeyFile;
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
  options.openwrt.config-auto-deploy = {
    enable = mkEnableOption "Automatic deployment when derivation changes";

    configs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          drv = mkOption {
            type        = types.package;
            description = "OpenWRT configuration derivation to deploy";
          };
          serviceName = mkOption {
            type        = types.nullOr types.str;
            default     = cfg.defaultServiceName;
            description = "Service this config is associated with (optional)";
          };
          host = mkOption {
            type        = types.str;
            description = "Host to deploy to. Used for SSH connection probing/waiting before deployment";
          };
        };
      });
      default     = {};
      description = "Set of OpenWRT configurations to deploy";
    };
  };

  ## create one systemd service per config
  config = mkIf cfg.enable {
    systemd.services = mapAttrs (n: opts: makeService {
      name        = n;
      drv         = opts.drv;
      imageDrv    = opts.imageDrv;
      serviceName = opts.serviceName;
      host        = opts.host;
    }) cfg.configs;
  };
}
