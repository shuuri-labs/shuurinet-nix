{ inputs }:

let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  profiles = inputs.openwrt-imagebuilder.lib.profiles { inherit pkgs; };
in {
  # Default router image
  berlin-router-img2 = 
    let
      config = {
        target = "x86";
        variant = "64";
        profile = "generic";
        release = "24.10.0";
        
        packages = [
          "luci-app-sqm"
          "attendedsysupgrade-common"
          "avahi-daemon-service-http"
          "avahi-daemon-service-ssh"
        ];
        
        # Include custom files and configurations
        files = pkgs.runCommand "router-files" {} ''
          mkdir -p $out/etc/uci-defaults
          mkdir -p $out/etc/dropbear

          # UCI config script
          cat > $out/etc/uci-defaults/99-custom <<EOF
          uci -q batch << EOI
          set system.@system[0].hostname='ludicolo-router'
          set network.lan.ipaddr='192.168.11.51'
          commit
          EOI
          EOF

          # SSH authorized key
          cat > $out/etc/dropbear/authorized_keys <<EOF
          cp /home/ashley/id_ed25519.pub $out/etc/dropbear/authorized_keys
          EOF
        '';

        # Increase root filesystem size to 1GB
        rootFsPartSize = 1024;
      };
    in
      inputs.openwrt-imagebuilder.lib.build config;
  
  # You can add more router images here
  berlin-ap = 
    let
      config = profiles.identifyProfile "xiaomi_redmi-router-ax6s" // {
        target = "mediatek/mt7622";
        variant = "generic";
        profile = "xiaomi_redmi-router-ax6s";
        release = "snapshot";
        packages = [
          "luci"
        ];
        disabledServices = [ "dnsmasq" "odhcpd" ];
        files = pkgs.runCommand "ap-files" {} ''
          mkdir -p $out/etc/uci-defaults
          cat > $out/etc/uci-defaults/99-custom <<EOF
          uci -q batch << EOI
          set system.@system[0].hostname='shuurinet-router'
          set network.lan.ipaddr='192.168.11.3'
          commit
          EOI
          EOF

          # SSH authorized key
          cat > $out/etc/dropbear/authorized_keys <<EOF
          ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCE43XNmeYWA9gw1DrhPf0T12OlGyJTZme097LJ0nvc ashleyamo982@gmail.com
          EOF
        '';
      };
    in
      inputs.openwrt-imagebuilder.lib.build config;
}