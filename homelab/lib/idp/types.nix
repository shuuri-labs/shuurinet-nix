{ lib }:
let
  inherit (lib) mkOption types mkEnableOption;
in
{
  userType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create this user";
      };

      name = mkOption {
        type = types.str;
        description = "The name of the user";
      };

      email = mkOption {
        type = types.str;
        description = "The email of the user";
      };
    };
  };

  serviceType = types.submodule ({ config, ... }: {
    options = {
      enable = mkEnableOption "Enable IDP for this service";

      name = mkOption {
        type = types.str;
        description = "The name of the service";
      };
      
      members = mkOption {
        type = types.listOf types.str;
        default = [ "ashley" ]; # TODO: members should also be dynamically defaulted
        description = "The members of the service";
      };

      originUrls = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "The origin URLs of the service";
      };

      originLanding = mkOption {
        type = types.str;
        default = "";
        description = "The origin landing page of the service";
      };

      oidc = {
        configurationUrl = mkOption {
          type = types.str;
          default = ""; # TODO: set this dynamically
          description = "The OIDC configuration URL of the service";
        };

        clientId = mkOption {
          type = types.str;
          default = config.name;
          description = "The OIDC client ID of the service";
        };

        clientSecret = mkOption {
          type = types.str;
          default = ""; # TODO: set this dynamically (?)
          description = "The OIDC client secret of the service";
        };

        scopes = mkOption {
          type = types.listOf types.str;
          default = [
            "openid"
            "email"
            "profile"
          ];
          description = "The OIDC scopes of the service";
        };
      };

      public = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the service is public";
      };

      localhostRedirects = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to allow localhost redirects";
      };

      extraAttributes = mkOption {
        type = types.attrs;
        default = {};
        description = "Extra attributes to add to the service";
      };
    };
  });
} 