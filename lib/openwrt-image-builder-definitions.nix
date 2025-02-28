{ inputs }:

let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  profiles = inputs.openwrt-imagebuilder.lib.profiles { inherit pkgs; };
in {
  # Default router image
  berlin-router = 
    let
      config = {
        target = "x86";
        variant = "64";
        profile = "generic";
        release = "24.10.0";
        
        packages = [
          "tcpdump"
          "luci-app-sqm"
          "attendedsysupgrade-common"
          "avahi-daemon-service-http"
          "avahi-daemon-service-ssh"
          "ethtool"
          "pciutils"
        ];
        
        # Include custom files and configurations
        files = pkgs.runCommand "openwrt-files" {} ''
          mkdir -p $out/etc/uci-defaults
          cat > $out/etc/uci-defaults/99-custom <<EOF
          uci -q batch << EOI
          set system.@system[0].hostname='ludicolo-router'
          commit
          EOI
          EOF
        '';
        
        # Increase root filesystem size to 4GB
        rootFsPartSize = 4096;
      };
    in
      inputs.openwrt-imagebuilder.lib.build config;
  
  # You can add more router images here
  berlin-ap = 
    let
      config = profiles.identifyProfile "xiaomi_redmi-router-ax6s" // {
        release = "SNAPSHOT";
        packages = [
          "luci"
          "tcpdump"
        ];
        files = pkgs.runCommand "fritz-files" {} ''
          mkdir -p $out/etc/uci-defaults
          cat > $out/etc/uci-defaults/99-custom <<EOF
          uci -q batch << EOI
          set system.@system[0].hostname='fritz-router'
          commit
          EOI
          EOF
        '';
      };
    in
      inputs.openwrt-imagebuilder.lib.build config;
}