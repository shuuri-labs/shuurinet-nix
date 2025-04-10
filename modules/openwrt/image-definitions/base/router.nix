{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  
  base = import ./base.nix { inherit inputs; };

  mkSqmConfig = {
    queue,
    interface,
    enabled ? true,
    download,
    upload,
    linklayer ? "ethernet",
    overhead
  }: ''
    config queue '${queue}'
      option enabled ${if enabled then "1" else "0"}
      option interface '${interface}'
      option download '${toString download}'
      option upload '${toString upload}'
      option qdisc 'cake'
      option script 'piece_of_cake.qos'
      option linklayer '${linklayer}'
      option debug_logging '0'
      option verbosity '5'
      option overhead '${toString overhead}'
  '';

  # Router-specific configuration builder
  mkRouterConfig = args@{ 
    hostname,
    ipAddress,
    target,
    variant,
    profile,
    release ? "24.10.0",
    rootFsPartSize ? null,
    extraPackages ? [],
    sqmConfig ? null,
    ...
  }: base.mkBaseConfig (args // {
    extraPackages = [
      "avahi-daemon-service-http"
      "avahi-daemon-service-ssh"
      "luci-app-sqm"
    ] ++ extraPackages;

    # Router-specific files
    extraFiles = args.extraFiles or "" + ''
      # Add router-specific configurations
      mkdir -p $out/etc/config
      
      # SQM config (if provided)
      ${if sqmConfig != null then ''
        cat > $out/etc/config/sqm.apk-new <<EOF
        ${mkSqmConfig sqmConfig}
        EOF
      '' else ""}
    '';

    inherit rootFsPartSize;
  });

in {
  inherit mkRouterConfig;
}