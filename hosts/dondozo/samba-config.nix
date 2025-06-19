{ config, hostname, ... }:
let
  network = config.homelab.system.network; 
  storage = config.homelab.system.storage;
in
{
  homelab.lib.smb.provisioner = {
    hostName = config.networking.hostName;
    hostIp = "${network.primaryBridge.address}/32";
    users = [
      { name = "ashley"; 
        passwordFile = config.age.secrets.ashley-samba-user-pw.path; 
      }
      { 
        name = "media"; 
        passwordFile = config.age.secrets.media-samba-user-pw.path; 
        createHostUser = true; # samba needs a user to exist for the samba users to be created
        extraGroups = [ storage.accessGroups.media.name ]; 
      }
      {
        name = "home-assistant-backup";
        passwordFile = config.age.secrets.home-assistant-backup-samba-user-pw.path;
        createHostUser = true;
        extraGroups = [ storage.accessGroups.backups.name ];
      }
    ];
  };

  services.samba.settings = {
    shuurinet-rust = {
      browseable = "yes";
      comment = "${hostname} Rust Pool";
      "guest ok" = "no";
      path = storage.paths.bulkStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    shuurinet-data = {
      browseable = "yes";
      comment = "${hostname} Rust Pool";
      "guest ok" = "no";
      path = storage.paths.fastStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    shuurinet-editing = {
      browseable = "yes";
      comment = "${hostname} Rust Pool";
      "guest ok" = "no";
      path = storage.paths.editingStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley";
    };
    media = {
      browseable = "yes";
      comment = "${hostname} Rust Pool";
      "guest ok" = "no";
      path = "${storage.directories.media}";
      writable = "yes";
      public = "yes";
      "read only" = "yes";
      "valid users" = "ashley media"; 
    };
    home-assistant-backups = {
      browseable = "yes";
      comment = "${hostname} Home Assistant Backups";
      "guest ok" = "no";
      path = "${storage.directories.backups}/home-assistant";
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley home-assistant-backup";
    };
  };
}