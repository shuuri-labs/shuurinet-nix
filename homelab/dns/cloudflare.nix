{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.dns.cloudflare;
  dnsCfg = config.homelab.dns;
  inherit (lib) mkOption mkEnableOption types mkIf mkMerge escapeShellArg;
  
  # Script to manage a single DNS record
  manageDnsRecord = record: pkgs.writeShellScript "manage-dns-record-${record.name}" ''
    set -euo pipefail
    
    # Load environment variables
    source ${cfg.credentialsFile}
    
    ZONE_ID="$CLOUDFLARE_ZONE_ID"
    EMAIL="$CLOUDFLARE_EMAIL"
    API_KEY="$CLOUDFLARE_API_KEY"
    
    RECORD_NAME="${record.name}"
    RECORD_TYPE="${record.type}"
    RECORD_CONTENT="${record.content}"
    RECORD_PROXIED="${if record.proxied then "true" else "false"}"
    RECORD_TTL="${toString record.ttl}"
    RECORD_COMMENT="${record.comment}"
    
    echo "Managing DNS record: $RECORD_NAME ($RECORD_TYPE)"
    
    # Check if record exists
    EXISTING_RECORD=$(${pkgs.curl}/bin/curl -s \
      -H "X-Auth-Email: $EMAIL" \
      -H "X-Auth-Key: $API_KEY" \
      -H "Content-Type: application/json" \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME&type=$RECORD_TYPE" \
      | ${pkgs.jq}/bin/jq -r '.result[0].id // "null"')
    
    if [ "$EXISTING_RECORD" = "null" ]; then
      echo "Creating new DNS record..."
      ${pkgs.curl}/bin/curl -s \
        -X POST \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
          \"type\": \"$RECORD_TYPE\",
          \"name\": \"$RECORD_NAME\",
          \"content\": \"$RECORD_CONTENT\",
          \"ttl\": $RECORD_TTL,
          \"proxied\": $RECORD_PROXIED,
          \"comment\": \"$RECORD_COMMENT\"
        }" \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        | ${pkgs.jq}/bin/jq -r '.success'
    else
      echo "Updating existing DNS record (ID: $EXISTING_RECORD)..."
      ${pkgs.curl}/bin/curl -s \
        -X PUT \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
          \"type\": \"$RECORD_TYPE\",
          \"name\": \"$RECORD_NAME\",
          \"content\": \"$RECORD_CONTENT\",
          \"ttl\": $RECORD_TTL,
          \"proxied\": $RECORD_PROXIED,
          \"comment\": \"$RECORD_COMMENT\"
        }" \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING_RECORD" \
        | ${pkgs.jq}/bin/jq -r '.success'
    fi
  '';

  # Create systemd services for each DNS record
  dnsRecordServices = lib.listToAttrs (map (record: {
    name = "dns-record-${record.name}";
    value = {
      description = "Manage DNS record for ${record.name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${manageDnsRecord record}";
        User = "cloudflare-dns";
        Group = "cloudflare-dns";
        
        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
      };
      
      # Restart policy
      unitConfig = {
        StartLimitBurst = 3;
        StartLimitIntervalSec = 300;
      };
    };
  }) dnsCfg.records);

in
{
  options.homelab.dns.cloudflare = {
    enable = mkEnableOption "Cloudflare DNS management";
    
    credentialsFile = mkOption {
      type = types.path;
      description = ''
        Path to file containing Cloudflare credentials.
        Should contain:
          CLOUDFLARE_ZONE_ID=your_zone_id
          CLOUDFLARE_EMAIL=your_email
          CLOUDFLARE_API_KEY=your_api_key
      '';
    };
    
    publicIp = mkOption {
      type = types.str;
      description = "Public IP address to use for A records";
    };
  };

  config = mkIf (cfg.enable && dnsCfg.enable && dnsCfg.provider == "cloudflare") {
    # Create dedicated user for DNS management
    users.users.cloudflare-dns = {
      isSystemUser = true;
      group = "cloudflare-dns";
      description = "Cloudflare DNS management user";
    };
    
    users.groups.cloudflare-dns = {};
    
    # Create systemd services for each DNS record
    systemd.services = dnsRecordServices;
    
    # Timer to periodically check and update DNS records
    systemd.timers = lib.listToAttrs (map (record: {
      name = "dns-record-${record.name}";
      value = {
        description = "Timer for DNS record ${record.name}";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "1h";
          Persistent = true;
        };
      };
    }) dnsCfg.records);
  };
} 