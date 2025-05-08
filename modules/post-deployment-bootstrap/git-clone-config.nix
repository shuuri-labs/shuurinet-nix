{ config, lib, pkgs, ... }:
let
  cfg = config.deploymentBoostrap.gitCloneConfig;
in
{
  options.deploymentBoostrap.gitCloneConfig = {
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
      default = "deploy-${config.host}";
      description = "Branch name to clone";
    };
  };

  config = lib.mkIf cfg.enabled {
    systemd.services.git-clone-config = {
      description = "Git clone nix config";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.user;
        ExecStart = ''
          clone_repo() {
            if ${pkgs.git}/bin/git ls-remote --heads https://github.com/${cfg.githubAccount}/${cfg.repo}.git ${cfg.branch} | grep -q ${cfg.branch}; then
              ${pkgs.git}/bin/git clone -b ${cfg.branch} https://github.com/${cfg.githubAccount}/${cfg.repo}.git ~/${cfg.repo}
            else
              echo "Branch ${cfg.branch} not found, falling back to develop"
              ${pkgs.git}/bin/git clone -b develop https://github.com/${cfg.githubAccount}/${cfg.repo}.git ~/${cfg.repo}
            fi
          }

          if [ -d ~/${cfg.repo} ]; then
            # Check if directory only contains secrets folder
            if [ "$(ls -A ~/${cfg.repo} | grep -v '^secrets$' | wc -l)" -eq 0 ]; then
              rm -rf ~/${cfg.repo}
              clone_repo
            else
              echo "Config directory contains files other than secrets folder, skipping clone"
              exit 0
            fi
          else
            clone_repo
          fi
        '';
      };
    };
  };
}