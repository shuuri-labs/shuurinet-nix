{config, lib, ...}:

let
  hostCfgVars = config.host.vars;
in
{
  sambaProvisioner.hostName = hostCfgVars.network.config.hostName;
  sambaProvisioner.hostIp = "${hostCfgVars.network.config.hostAddress}/32";
  sambaProvisioner.users = [
    { name = "ashley"; 
      passwordFile = config.age.secrets.ashley-samba-user-pw.path; 
    }
    { 
      name = "media"; 
      passwordFile = config.age.secrets.media-samba-user-pw.path; 
      createHostUser = true; # samba needs a user to exist for the samba users to be created
      extraGroups = [ config.host.storage.accessGroups.media.name ]; 
    } 
  ];

  services.samba.settings = {
    castform-rust = {
      browseable = "yes";
      comment = "${hostCfgVars.network.config.hostName} Rust Pool";
      "guest ok" = "no";
      path = hostCfgVars.storage.paths.bulkStorage;
      writable = "yes";
      public = "yes";
      "read only" = "no";
      "valid users" = "ashley media"; # todo: dynamic based on user definitions above
    };
  };
}