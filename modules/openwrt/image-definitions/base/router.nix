{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  
  base = import ./base.nix { inherit inputs; };

  # Router-specific configuration builder
  mkRouterConfig = args@{ 
    hostname,
    ipAddress,
    target,
    variant,
    profile,
    rootFsPartSize ? null,
    extraPackages ? [],
    ...
  }: base.mkBaseConfig (args // {
    extraPackages = [
      "avahi-daemon-service-http"
      "avahi-daemon-service-ssh"
      "luci-app-sqm"
    ] ++ extraPackages;

    # Router-specific files
    # extraFiles = args.extraFiles or "" + ''
    #   # Add router-specific configurations
    #   mkdir -p $out/etc/config
      
    #   # SQM config (if provided)
    #   ${if sqmConfig != null then ''
    #     cat > $out/etc/config/sqm.apk-new <<EOF
    #     ${mkSqmConfig sqmConfig}
    #     EOF
    #   '' else ""}
    # '';

    inherit rootFsPartSize;
  });

in {
  inherit mkRouterConfig;
}