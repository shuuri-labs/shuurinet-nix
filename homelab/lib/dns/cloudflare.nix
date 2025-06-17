{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.lib.dns.cloudflare;
  dnsCfg = config.homelab.lib.dns;
  
  inherit (lib) mkOption mkEnableOption types mkIf mkMerge escapeShellArg;
  
  # Script to manage a single DNS record
  manageDnsRecord = record: pkgs.writeShellScript "manage-dns-record-${record.name}" ''
    set -euo pipefail
    
    # Load environment variables
    source ${cfg.credentialsFile}
    
    ZONE_ID="$CLOUDFLARE_ZONE_ID"
    API_TOKEN="$CLOUDFLARE_API_KEY"
    
    RECORD_NAME="${record.name}"
    RECORD_TYPE="${record.type}"
    RECORD_CONTENT="${record.content}"
    RECORD_PROXIED="${if record.proxied then "true" else "false"}"
    RECORD_TTL="${toString record.ttl}"
    RECORD_COMMENT="${record.comment}"
    
    echo "Managing DNS record: $RECORD_NAME ($RECORD_TYPE)"
    
    # Check if record exists
    LOOKUP_RESPONSE=$(${pkgs.curl}/bin/curl -s \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME&type=$RECORD_TYPE")
    
    echo "Lookup response: $LOOKUP_RESPONSE"
    
    EXISTING_RECORD=$(echo "$LOOKUP_RESPONSE" | ${pkgs.jq}/bin/jq -r '.result[0].id // "null"')
    
    echo "Existing record ID: $EXISTING_RECORD"
    
    if [ "$EXISTING_RECORD" = "null" ]; then
      echo "Creating new DNS record..."
      RESPONSE=$(${pkgs.curl}/bin/curl -s \
        -X POST \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
          \"type\": \"$RECORD_TYPE\",
          \"name\": \"$RECORD_NAME\",
          \"content\": \"$RECORD_CONTENT\",
          \"ttl\": $RECORD_TTL,
          \"proxied\": $RECORD_PROXIED,
          \"comment\": \"$RECORD_COMMENT\"
        }" \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records")
      echo "Create API Response: $RESPONSE"
      
      SUCCESS=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.success')
      if [ "$SUCCESS" = "false" ]; then
        echo "Creation failed. Checking if record exists now..."
        # Retry lookup in case record was created by another process
        RETRY_LOOKUP=$(${pkgs.curl}/bin/curl -s \
          -H "Authorization: Bearer $API_TOKEN" \
          -H "Content-Type: application/json" \
          "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME&type=$RECORD_TYPE")
        RETRY_RECORD=$(echo "$RETRY_LOOKUP" | ${pkgs.jq}/bin/jq -r '.result[0].id // "null"')
        
        if [ "$RETRY_RECORD" != "null" ]; then
          echo "Record exists after creation failure. Updating instead..."
          EXISTING_RECORD="$RETRY_RECORD"
        else
          echo "Creation genuinely failed: $(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.errors')"
          exit 1
        fi
      else
        echo "Record created successfully"
        exit 0
      fi
    fi
    
    if [ "$EXISTING_RECORD" != "null" ]; then
      echo "Updating existing DNS record (ID: $EXISTING_RECORD)..."
      RESPONSE=$(${pkgs.curl}/bin/curl -s \
        -X PUT \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
          \"type\": \"$RECORD_TYPE\",
          \"name\": \"$RECORD_NAME\",
          \"content\": \"$RECORD_CONTENT\",
          \"ttl\": $RECORD_TTL,
          \"proxied\": $RECORD_PROXIED,
          \"comment\": \"$RECORD_COMMENT\"
        }" \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING_RECORD")
      echo "API Response: $RESPONSE"
      echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.success'
    fi
  '';

  # Create systemd services for each DNS record
  dnsRecordServices = lib.listToAttrs (lib.mapAttrsToList (recordName: record: {
    name = "dns-record-${record.name}";
    value = {
      description = "Manage DNS record for ${record.name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      
      # Restart when DNS record configuration changes
      restartTriggers = [ (builtins.toJSON record) ];
      
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
  options.homelab.lib.dns.cloudflare = {
    enable = mkEnableOption "Cloudflare DNS management";
    
    credentialsFile = mkOption {
      type = types.path;
      description = ''
        Path to file containing Cloudflare credentials.
        Should contain:
          CLOUDFLARE_ZONE_ID=your_zone_id
          CLOUDFLARE_API_KEY=your_api_token (API Token, not Global API Key)
        
        Note: This uses Cloudflare API Token authentication, not the legacy Global API Key.
        Create an API Token at https://dash.cloudflare.com/profile/api-tokens
      '';
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
    
    # Automatically create systemd services for each DNS record under homelab.dns.records
    systemd.services = dnsRecordServices;
  };
} 