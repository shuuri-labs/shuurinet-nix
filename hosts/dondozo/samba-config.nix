{config, hostMainIp, ...}:

let
  hostCfgVars = config.host.vars;
in
{
  sambaProvisioner = {
    hostName = hostCfgVars.network.hostName;
    hostIp = "${hostMainIp}/32";
    users = [
      { name = "ashley"; 
        passwordFile = config.age.secrets.ashley-samba-user-pw.path; 
      }
      { 
        name = "media"; 
        passwordFile = config.age.secrets.media-samba-user-pw.path; 
        createHostUser = true; # samba needs a user to exist for the samba users to be created
        extraGroups = [ hostCfgVars.storage.accessGroups.media.name ]; 
      }
      {
        name = "home-assistant-backup";
        passwordFile = config.age.secrets.home-assistant-backup-samba-user-pw.path;
        createHostUser = true;
        extraGroups = [ hostCfgVars.storage.accessGroups.backups.name ];
      }
    ];
  };

  services.samba.settings = {
    shuurinet-rust = {
      browseable = "yes";
      comment = "${hostCfgVars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = hostCfgVars.storage.paths.bulkStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    shuurinet-data = {
      browseable = "yes";
      comment = "${hostCfgVars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = hostCfgVars.storage.paths.fastStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    shuurinet-editing = {
      browseable = "yes";
      comment = "${hostCfgVars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = hostCfgVars.storage.paths.editingStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    media = {
      browseable = "yes";
      comment = "${hostCfgVars.network.hostName} Rust Pool";
      "guest ok" = "no";
      path = "${hostCfgVars.storage.directories.media}";
      writable = "yes";
      public = "yes";
      "read only" = "yes";
      "valid users" = "ashley media"; 
    };
    home-assistant-backups = {
      browseable = "yes";
      comment = "${hostCfgVars.network.hostName} Home Assistant Backups";
      "guest ok" = "no";
      path = "${hostCfgVars.storage.directories.backups}/home-assistant";
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley home-assistant-backup";
    };
  };
}