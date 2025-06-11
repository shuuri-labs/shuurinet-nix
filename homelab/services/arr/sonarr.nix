{ config, lib, pkgs, ... }:
let
  service = "sonarr";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;

  common = import ../common.nix { inherit lib config homelab service; };
in
{
  options.homelab.services.${service} = common.options // {
    # --- Common Overrides ---
    
    port = lib.mkOption {
      type = lib.types.int;
      default = 8989;
      description = "Port to run the ${service} service on";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ 
        homelab.storage.accessGroups.downloads.name 
      ];
      description = "Additional groups for ${service} user";
    };

    # --- ${service} Specific ---

    group = lib.mkOption {
      type = lib.types.str;
      default = homelab.storage.accessGroups.media.name;
      description = "Primary group for ${service} user";
    };
  };

  config = lib.mkMerge [
    common.config
    
    (lib.mkIf cfg.enable {
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