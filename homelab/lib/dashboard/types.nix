{ lib }:
let
  inherit (lib) mkOption types;
in
{
  entryType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to display this entry in the dashboard";
      };

      section = mkOption {
        type = types.str;
        default = "Services";
        description = "Section to display the entry in";
      };

      icon = mkOption {
        type = types.str;
        default = "";
        description = "Icon to display for the entry";
      };

      href = mkOption {
        type = types.str;
        default = "";
        description = "URL to navigate to when the entry is clicked";
      };

      siteMonitor = mkOption {
        type = types.str;
        default = "";
        description = "URL to monitor the entry";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Description to display for the entry";
      };

      widget = mkOption {
        type = types.attrs;
        default = {};
        description = "Widget to display for the entry";
      };
    };
  };
} 