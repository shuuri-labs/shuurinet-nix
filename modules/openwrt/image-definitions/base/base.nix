{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  profiles = inputs.openwrt-imagebuilder.lib.profiles { inherit pkgs; };

  hostKey = builtins.readFile /home/ashley/.ssh/id_ed25519.pub;
  laptopKey = builtins.readFile /home/ashley/shuurinet-nix/secrets/keys/laptop-key.pub;

  openWrtVersion = "24.10.1";
  # Common function to create router configurations
  mkBaseConfig = { 
    hostname,
    ipAddress,
    gateway ? null,
    dnsServer ? null,
    target,
    variant,
    profile,
    release ? openWrtVersion,
    extraPackages ? [],
    extraServices ? [],
    disabledServices ? [],
    authorizedKeys ? [ hostKey laptopKey ],
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

  # Helper function to generate image name
  mkImageName = {
    version ? openWrtVersion,  # Use openwrtVersion instead of version
    target ? "x86-64",
    profile ? "generic",
    type ? "ext4-combined-efi"
  }: "openwrt-${version}-${target}-${profile}-${type}.img.gz";

  qemuImage = pkgs.stdenv.mkDerivation rec {
    pname    = "qemu-image-${name}";
    version  = if img.sourceUrl != null 
               then builtins.substring 0 8 img.sourceSha256
               else "1";
  };
in {
  inherit mkBaseConfig mkImageName;
}