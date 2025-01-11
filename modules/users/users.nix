{ config, pkgs, lib, ... }:

{
  options.host.user = {
    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          username = lib.mkOption {
            type = lib.types.str;
            description = "The username for the account";
          };
          
          password = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "The user's password";
          };
          
          userDescription = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Description/full name of the user";
          };
          
          uid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "The user's uid. If null, NixOS will auto-assign one.";
          };
          
          groups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Groups the user belongs to";
          };
          
          home = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Home directory of the user";
          };
          
          isNormalUser = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether this is a normal user account";
          };
          
          sudo = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the user has sudo access";
          };
          
          ssh = lib.mkOption {
            type = lib.types.submodule {
              options = {
                passwordLogin = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether to allow SSH password login";
                };
              };
            };
            default = {};
            description = "SSH-related settings for the user";
          };
        };
      });
      default = {};
      description = "List of users with their properties.";
    };

    mainUsername = lib.mkOption {
      type = lib.types.str;
      default = "ashley";
      description = "Default username for main user";
    };

    mainUserDescription = lib.mkOption {
      type = lib.types.str;
      default = "Ashley";
      description = "Default description for main user";
    };

    mainUserPassword = lib.mkOption {
      type = lib.types.str;
      default = ""; # pkgs.agenix.decryptFile ./secrets/default-main-user-pw.age; 
      description = "Default password for main user (override in host config)";
    };

    sshKeys = lib.mkOption {
      type = lib.types.listOf.str;
      default = [];
      description = "";
    };
  };

  config = {
    users.groups = lib.mapAttrs' (name: user: lib.nameValuePair
      user.username  # Use this as the group name
      {
        gid = if user.uid != null then user.uid else null;  # Match GID to UID if specified
      }
    ) config.host.user.users;

    # host.user.users.mainUser = {
    #   username = config.host.user.mainUsername;
    #   password = config.host.user.mainUserPassword;
    #   userDescription = config.host.user.mainUserDescription;
    #   home = "/home/${config.host.user.mainUsername}";
    #   isNormalUser = true;
    #   sudo = true; 
    #   groups = ["networkmanager" "wheel" ];
    # };

    users.users = lib.mapAttrs (name: user: 
      lib.recursiveUpdate {
        inherit (user) isNormalUser;
        name = user.username;
        group = user.username;
        extraGroups = if user.sudo 
                      then user.groups ++ ["wheel"]
                      else user.groups;
        openssh.authorizedKeys.keys = config.common.sshKeys;
        hashedPasswordFile = lib.mkDefault null;
      } (lib.optionalAttrs (user.uid != null) { uid = user.uid; } //
         lib.optionalAttrs (user.password != null) { password = user.password; } //
         lib.optionalAttrs (user.home != null) { home = user.home; } //
         lib.optionalAttrs (user.userDescription != null) { description = user.userDescription; })
    ) config.host.user.users;

    # Configure SSH password authentication for each user
    services.openssh.settings = {
      PasswordAuthentication = false;  # Disable by default
    };

    # Add sudo configuration if needed
    security.sudo.extraRules = lib.mapAttrsToList (name: user: {
      users = [ user.username ];
      commands = [{
        command = "ALL";
        options = [ "NOPASSWD" ];  # Or configure as needed
      }];
    }) (lib.filterAttrs (name: user: user.sudo) config.host.user.users);
  };
}

