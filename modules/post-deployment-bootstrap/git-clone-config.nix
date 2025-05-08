{ config, lib, pkgs, ... }:
{
  options.deploymentBoostrap.gitCloneConfig = {
    enabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable git clone of nix config";
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

  config = lib.mkIf config.deploymentBoostrap.gitCloneConfig.enabled {
    systemd.services.git-clone-config = {
      description = "Git clone nix config";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          clone_repo() {
            if ${pkgs.git}/bin/git ls-remote --heads https://github.com/shuurinet/shuurinet-nix.git ${config.branch} | grep -q ${config.branch}; then
              ${pkgs.git}/bin/git clone -b ${config.branch} https://github.com/shuurinet/shuurinet-nix.git ~/shuurinet-nix
            else
              echo "Branch ${config.branch} not found, falling back to develop"
              ${pkgs.git}/bin/git clone -b develop https://github.com/shuurinet/shuurinet-nix.git ~/shuurinet-nix
            fi
          }

          if [ -d ~/shuurinet-nix ]; then
            # Check if directory only contains secrets folder
            if [ "$(ls -A ~/shuurinet-nix | grep -v '^secrets$' | wc -l)" -eq 0 ]; then
              rm -rf ~/shuurinet-nix
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