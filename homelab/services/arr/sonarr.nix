{ config, lib, pkgs, ... }:
let
  service = "sonarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options;

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
      homelab.services.${service} = {
        port = lib.mkDefault 8989;
        group = lib.mkDefault homelab.storage.accessGroups.media.name;
        extraGroups = lib.mkDefault [ homelab.storage.accessGroups.downloads.name ];
      };

      nixpkgs.config.permittedInsecurePackages = [
        "aspnetcore-runtime-6.0.36"
        "aspnetcore-runtime-wrapped-6.0.36"
        "dotnet-sdk-6.0.428"
        "dotnet-sdk-wrapped-6.0.428"
      ];

      services.${service} = {
        enable = true;
        group = cfg.group;
        settings = {
          server.port = cfg.port;
        };
      };

      users.users.${service}.extraGroups = cfg.extraGroups;
      systemd.services.${service}.serviceConfig.UMask = "0002";
    })
  ];
}