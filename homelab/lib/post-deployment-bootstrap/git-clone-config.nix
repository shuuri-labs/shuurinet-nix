{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.lib.deployment.bootstrap.git;

  cloneCmd = pkgs.writeScript "git-clone-config.sh" ''
    #!${pkgs.bash}/bin/bash
    set -e

    if [ -d ~/${cfg.repo} ]; then
      # Check if directory only contains secrets folder
      if [ "$(${pkgs.coreutils}/bin/ls -A ~/${cfg.repo} | ${pkgs.gnugrep}/bin/grep -v '^\.$' | ${pkgs.gnugrep}/bin/grep -v '^\.\.$' | ${pkgs.gnugrep}/bin/grep -v '^secrets$' | ${pkgs.coreutils}/bin/wc -l)" -eq 0 ]; then
        echo "Directory exists but only contains secrets folder, proceeding with clone"
        rm -rf ~/${cfg.repo}
      else
        echo "Config directory contains files other than secrets folder, skipping clone"
        exit 0
      fi
    fi

    echo "Cloning repository..."
    REPO_URL="git@github.com:${cfg.githubAccount}/${cfg.repo}.git"
    CLONE_CMD="${pkgs.git}/bin/git clone --recurse-submodules"

    # Give network a moment to fully initialize
    ${pkgs.coreutils}/bin/sleep 10

    # Ensure SSH agent is running and has the correct socket
    if [ -z "$SSH_AUTH_SOCK" ]; then
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
    fi

    # Add GitHub to known hosts
    mkdir -p ~/.ssh
    ${pkgs.openssh}/bin/ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

    if ${pkgs.git}/bin/git ls-remote --heads $REPO_URL ${cfg.branch} | ${pkgs.gnugrep}/bin/grep -q ${cfg.branch}; then
      GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no" $CLONE_CMD -b ${cfg.branch} $REPO_URL ~/${cfg.repo}
    else
      echo "Branch ${cfg.branch} not found, falling back to develop"
      GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no" $CLONE_CMD -b develop $REPO_URL ~/${cfg.repo}
    fi

    cd ~/${cfg.repo}/secrets
    ${pkgs.git}/bin/git checkout develop

    cd ~/${cfg.repo}
    ${pkgs.git}/bin/git add *
  '';
in
{
  options.homelab.lib.deployment.bootstrap.git = {
    enabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable git clone of nix config";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "ashley";
      description = "User name";
    };

    githubAccount = lib.mkOption {
      type = lib.types.str;
      default = "shuuri-labs";
      description = "Github account name";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "shuurinet-nix";
      description = "Repository name";
    };
    
    host = lib.mkOption {
      type = lib.types.str;
      description = "Host name";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "deploy-${cfg.host}";
      description = "Branch name to clone";
    };
  };

  config = lib.mkIf cfg.enabled {
    systemd.services.git-clone-config = {
      description = "Git clone nix config";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "systemd-resolved.service"
        "ssh-agent.service"
        "systemd-networkd.service"
        "network.target"
        "nss-lookup.target"
      ];
      wants = [
        "network-online.target"
        "systemd-resolved.service"
        "ssh-agent.service"
        "systemd-networkd.service"
        "network.target"
        "nss-lookup.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.user;
        ExecStart = "${cloneCmd}";
        Environment = [
          "PATH=${lib.makeBinPath [ pkgs.git pkgs.openssh pkgs.coreutils pkgs.gnugrep ]}:$PATH"
          "XDG_RUNTIME_DIR=/run/user/$(id -u ${cfg.user})"
        ];
      };
    };
  };
}