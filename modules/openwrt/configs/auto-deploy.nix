{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.openwrt.config-auto-deploy;
  
  # Service for monitoring a config derivation for changes and applying
  makeService = { name, drv, serviceName ? null }: {
    description = "Auto-deploy ${name} when derivation changes";
    
    after    = [ "network-online.target" ] ++ (if serviceName != null then [ "${serviceName}.service" ] else []);
    wants    = [ "network-online.target" ] ++ (if serviceName != null then [ "${serviceName}.service" ] else []);
    wantedBy = [ "multi-user.target" ];
    
    environment = {
      NIX_PATH = "nixpkgs=${pkgs.path}";
      PATH = mkForce (lib.makeBinPath [ 
        pkgs.coreutils      # Basic Unix tools (cp, mkdir, etc.)
        pkgs.bash           # Bash shell
        pkgs.findutils      # find, xargs
        pkgs.gnugrep        # grep
        pkgs.systemd        # systemctl, etc.
        pkgs.util-linux     # getopt
        pkgs.openssh        # ssh, scp
        pkgs.gawk           # awk
        pkgs.gnused         # sed
        pkgs.jq             # JSON processing
        pkgs.sops           # Secret management
        pkgs.procps         # ps, top, etc.
        pkgs.iproute2       # ip, etc.
        pkgs.nettools       # netstat, etc.
        pkgs.which          # which command
        pkgs.mktemp         # mktemp command (though part of coreutils)
        pkgs.less           # less command
        pkgs.logger         # logger command
      ]);

      SOPS_AGE_KEY_FILE = mkIf (cfg.sopsAgeKeyFile != null) cfg.sopsAgeKeyFile;
    };
    
    # Trigger a restart whenever the derivation changes
    restartTriggers = [
      drv
    ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = ''${pkgs.writeShellScript "deploy-${name}" ''
        #!/usr/bin/env bash
        set -euo pipefail  # Exit on errors
        set -x  # Enable command tracing for debugging
        
        # Check for SOPS key
        if [ -z "''${SOPS_AGE_KEY_FILE:-}" ]; then
          echo "WARNING: SOPS_AGE_KEY_FILE is not set. Secret decryption may fail."
        elif [ ! -f "''${SOPS_AGE_KEY_FILE}" ]; then
          echo "WARNING: SOPS age key file not found at ''${SOPS_AGE_KEY_FILE}"
        else
          echo "SOPS age key file found at ''${SOPS_AGE_KEY_FILE}"
        fi
        
        DEPLOY_SCRIPT="${drv}/bin/deploy-${name}"
        echo "Checking deployment script at: $DEPLOY_SCRIPT"
        
        echo "Waiting 30 seconds for OpenWRT to start..."
        sleep 30
        echo "Proceeding with deployment"
        
        echo "Executing: $DEPLOY_SCRIPT"
        (
          "$DEPLOY_SCRIPT"
          RESULT=$?
          if [ $RESULT -ne 0 ]; then
            echo "ERROR: Deployment failed with exit code $RESULT"
            exit $RESULT
          fi
        ) || {
          echo "ERROR: Deployment failed"
          exit 1
        }
        
        echo "Deployment complete. Changes will rollback if unsuccessful"
      ''}'';
      
      # Increase the logging for this service
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
  
in {
  options.openwrt.config-auto-deploy = {
    enable = mkEnableOption "Automatic deployment when derivation changes";
    
    configs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          drv = mkOption {
            type = types.package;
            description = "The OpenWRT configuration derivation to deploy";
          };
          
          serviceName = mkOption {
            type = types.nullOr types.str;
            default = cfg.defaultServiceName;
            description = "The name of the service this config is associated with";
          };
        };
      });
      default = {};
      description = "Attribute set of OpenWRT configurations to deploy, where key is the name and value contains the derivation and associated service";
      example = literalExpression ''
        {
          berlin-router-config = {
            drv = pkgs.berlin-router-config;
            serviceName = "berlin-router";
          };
          berlin-ap-config = {
            drv = pkgs.berlin-ap-config;
          };
        }
      '';
    };
    
    sopsAgeKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/sops-age-key";
      description = "Path to the SOPS AGE key file for secret decryption";
    };
  };
  
  config = mkIf cfg.enable {
    systemd.services = 
      mapAttrs (name: configOpts: 
                  makeService { 
                    name = name; 
                    drv = configOpts.drv; 
                    serviceName = configOpts.serviceName; 
                  }
                ) cfg.configs;
  };
} 