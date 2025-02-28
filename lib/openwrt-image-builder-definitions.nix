{ inputs, ... }:

let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  profiles = inputs.openwrt-imagebuilder.lib.profiles { inherit pkgs; };

  # create a modified builder function that doesn't use <nixpkgs>
  buildImage = config: inputs.openwrt-imagebuilder.lib.build (config // { inherit pkgs; });

  commonPackages = [
    "luci"
    "luci-app-attendedsysupgrade"
    "ethtool"
    "nano"
    "htop"
  ];
in {
  berlin-router = 
    let
      config = {
        target = "x86";
        variant = "64";
        profile = "generic";
        release = "24.10.0";
        
        packages = commonPackages ++ [
          "luci-app-sqm"
          "avahi-daemon-service-http"
          "avahi-daemon-service-ssh"
          "ethtool"
          "tcpdump"
          "pciutils"
        ];
        
        files = pkgs.runCommand "openwrt-files" {} ''
          mkdir -p $out/etc/uci-defaults
          cat > $out/etc/uci-defaults/99-custom <<EOF
          #!/bin/sh
          
          # Get all ethernet ports
          ETH_PORTS=\$(ls /sys/class/net | grep -E '^eth|^lan|^wan' | tr '\n' ' ')
          
          uci -q batch << EOI
          set system.@system[0].hostname='shuurinet-router'
          
          # Create bridge interface and add all ethernet ports
          set network.br_lan=device
          set network.br_lan.name='br-lan'
          set network.br_lan.type='bridge'
          set network.br_lan.ports="@mac='52:54:00:aa:bb:cc'"

          set network.br_management=device
          set network.br_management.name='br-management'
          set network.br_management.type='bridge'
          set network.br_management.ports="@mac='52:54:00:aa:bb:dd'"
          
          # Set static IP for LAN interface and assign it to the bridge
          set network.lan.proto='static'
          set network.lan.device='br-lan'
          set network.lan.ipaddr='192.168.11.69'
          set network.lan.netmask='255.255.255.0'

          set network.management.proto='static'
          set network.management.device='br-lan'
          set network.management.ipaddr='10.10.55.1'
          set network.management.netmask='255.255.255.0'
          
          # Disable DHCP on LAN interface
          set dhcp.lan.ignore='1'
          
          commit
          EOI
          EOF
          
          # Make the script executable
          chmod +x $out/etc/uci-defaults/99-custom
        '';
        
        rootFsPartSize = 4096;
      };
    in
      buildImage config;
  
  berlin-ap = 
    let
      config = {
        target = "mediatek";
        variant = "mt7622";
        profile = "xiaomi_redmi-router-ax6s";
        release = "24.10.0";  # Use a stable release
        
        packages = commonPackages;

        files = pkgs.runCommand "fritz-files" {} ''
          mkdir -p $out/etc/uci-defaults
          cat > $out/etc/uci-defaults/99-custom <<EOF
          uci -q batch << EOI
          set system.@system[0].hostname='shuurinet-AP'
          commit
          EOI
          EOF
        '';
      };
    in
      buildImage config;
}

# nix build .#berlin-router
