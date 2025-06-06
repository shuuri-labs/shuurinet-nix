{ lib }:
let
  inherit (lib) mkOption types;
in
{
  hostType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create a reverse proxy for this host";
      };

      domain = mkOption {
        type = types.str;
        description = "Domain name for the reverse proxy";
      };

      backend = {
        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Backend server address";
        };

        port = mkOption {
          type = types.int;
          description = "Backend server port";
        };
      };
    };
  };
} 