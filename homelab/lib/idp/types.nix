{ lib }:
let
  inherit (lib) mkOption types;
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

  serviceType = types.submodule {
    options = {
      enable = mkEnableOption "Enable IDP for this service";

      name = mkOption {
        type = types.str;
        description = "The name of the service";
      };
      
      members = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "The members of the service";
      };

      originUrls = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "The origin URLs of the service";
      };

      originLanding = mkOption {
        type = types.str;
        default = "";
        description = "The origin landing page of the service";
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

      oidcScopes = mkOption {
        type = types.listOf types.attrs;
        default = [
          "openid"
          "email"
          "profile"
          "offline_access"
        ];
        description = "The OIDC roles of the service";
      };
    };
  };
} 