{ config, pkgs, lib, ... }:

{
  options.realTimeSync = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the real-time sync service for monitoring and copying files.";
    };

    pairs = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.str);
      default = [
        { source = "/path/to/default-downloads"; dest = "/path/to/default-archive"; }
      ];
      description = "List of directory pairs to sync, each with 'source' and 'dest' keys.";
    };
  };

  config = lib.mkIf config.realTimeSync.enable {
    # Dynamically create a systemd service for each source/destination pair
    systemd.services = lib.genAttrs
      (map (pair: builtins.hashString "md5" pair.source) config.realTimeSync.pairs)
      (pair: {
        description = "Real-time sync from ${pair.source} to ${pair.dest}";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.writeScriptBin "real_time_sync_${builtins.hashString "md5" pair.source}" ''
            #!/usr/bin/env bash

            WATCH_DIR=${pair.source}
            DEST_DIR=${pair.dest}
            LOG_FILE=/var/log/real_time_sync_${builtins.hashString "md5" pair.source}.log

            mkdir -p "$DEST_DIR"

            ${pkgs.inotify-tools}/bin/inotifywait -m -e create -e moved_to --format "%w%f" "$WATCH_DIR" | while read NEWFILE
            do
                echo "$(date): Detected new file $NEWFILE" >> "$LOG_FILE"
                ${pkgs.rsync}/bin/rsync -av --ignore-existing "$NEWFILE" "$DEST_DIR/"
                echo "$(date): Copied $NEWFILE to $DEST_DIR" >> "$LOG_FILE"
            done
          ''}'";
          Restart = "always";
          RestartSec = "10s";
        };
      }) config.realTimeSync.pairs;

    # Ensure required packages are available
    environment.systemPackages = with pkgs; [
      inotify-tools
      rsync
    ];

    # Create destination directories using tmpfiles
    systemd.tmpfiles.rules = map (pair: "d ${pair.dest} 0755 root root -") config.realTimeSync.pairs;
  };
}

### flake.nix (add to existing modules in outputs section)

modules = [
  ./modules/arr-ssd-caching.nix     # The real-time sync module
];

### configuration.nix

realTimeSync = {
    enable = true;
    pairs = [
      { source = "/home/user/downloads1"; dest = "/mnt/hdd/archive1"; }
      { source = "/home/user/downloads2"; dest = "/mnt/hdd/archive2"; }
    ];
};


