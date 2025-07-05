{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  profiles = inputs.openwrt-imagebuilder.lib.profiles { inherit pkgs; };

  # Import SSH keys from secrets - this is pure since it's a static file
  secrets = import /home/ashley/shuurinet-nix/secrets/secrets.nix;

  # Default SSH keys using the secrets system (these are known public keys)
  # These can be overridden by passing authorizedKeys parameter
  defaultAuthorizedKeys = [
    secrets.allKeys.tatsugiri
    secrets.allKeys.tatsugiri-user

    secrets.allKeys.missingno
    secrets.allKeys.missingno-user

    secrets.allKeys.dondozo
    secrets.allKeys.rotom
  ];

  # Common function to create router configurations
  mkBaseConfig = { 
    hostname,
    ipAddress,
    gateway ? null,
    dnsServer ? null,
    target,
    variant,
    profile,
    release ? "24.10.2",
    extraPackages ? [],
    extraServices ? [],
    disabledServices ? [],
    authorizedKeys ? defaultAuthorizedKeys,
    rootFsPartSize ? null,
    extraUciCommands ? "",
    extraFiles ? "",
    ...
  }: {
    inherit target variant profile release rootFsPartSize disabledServices;
    
    packages = [
      "luci"
      "attendedsysupgrade-common"
    ] ++ extraPackages;
    
    files = pkgs.runCommand "base-files" {} ''
      mkdir -p $out/etc/uci-defaults
      mkdir -p $out/etc/dropbear

      # UCI config script
      cat > $out/etc/uci-defaults/99-custom <<EOF
      uci -q batch << EOI
      set system.@system[0].hostname='${hostname}'
      set network.lan.ipaddr='${ipAddress}'
      set network.lan.gateway='${gateway}'
      set network.lan.dns='${dnsServer}'
      ${extraUciCommands}
      commit
      EOI
      EOF

      # SSH authorized keys
      cat > $out/etc/dropbear/authorized_keys <<EOF
      ${builtins.concatStringsSep "\n" authorizedKeys}
      EOF

      ${extraFiles}
    '';
  };
  
  # Function to create both configuration and image with accessible config
  mkBaseImage = args:
    let
      config = mkBaseConfig args;
      image = inputs.openwrt-imagebuilder.lib.build config;
    in
      image // { inherit config; };

in {
  inherit mkBaseConfig mkBaseImage;
  
  # Export the default keys for reference
  inherit defaultAuthorizedKeys;
}