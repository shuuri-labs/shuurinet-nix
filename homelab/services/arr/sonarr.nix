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
        group = lib.mkDefault homelab.system.storage.accessGroups.media.name;
        extraGroups = lib.mkDefault [ homelab.system.storage.accessGroups.downloads.name ];
      };

      homelab.lib.dashboard.entries.${service} = {
        section = "Media";
        description = "TV media management";
      };

      nixpkgs.config.permittedInsecurePackages = [
        "aspnetcore-runtime-6.0.36"
        "aspnetcore-runtime-wrapped-6.0.36"
        "dotnet-sdk-6.0.428"
        "dotnet-sdk-wrapped-6.0.428"
      ];

      services.${service} = {
        enable = true;
        user = cfg.user;
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