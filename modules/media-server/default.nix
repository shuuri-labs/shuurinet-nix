{ config, lib, pkgs, ... }:

let
  cfg = config.mediaServer;
in {
    imports = [
    ./options.nix
    ./wireguard-routing-container.nix
    ./arr-transmission-containers.nix
    # ./arr-ssd-caching.nix
    ./jelly.nix
  ];

  options.mediaServer = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable media server services";
    };
  };

  config = lib.mkIf cfg.enable {
    mediaServer.network.wg-mullvad.enable = true;
    mediaServer.arrMission.enable = true;
    mediaServer.arrMission.enableAnimeSonarr = true;
  };
}