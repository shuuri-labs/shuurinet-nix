{ lib }:
let
  inherit (lib) mkOption types;
  inherit (import ../dns/types.nix { inherit lib; }) dnsRecordType;
  inherit (import ../reverse-proxy/types.nix { inherit lib; }) hostType;
in
{
  domainType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable reverse proxy and DNS records for this domain";
      };

      host = mkOption {
        type = hostType;
        description = "Host configuration for the domain";
      };

      dns = mkOption {
        type = dnsRecordType;
        description = "DNS configuration for the domain";
      };
    };
  };
}
