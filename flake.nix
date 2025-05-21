{
  description = "shuurinet nix config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-virtualisation.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-openwrt.url = "github:NixOS/nixpkgs/nixos-24.11";
    
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

    dewclaw = {
      url = "github:MakiseKurisu/dewclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    openwrt-imagebuilder = {
      # Pinned to specific commit - only update this when you want new OpenWRT images
      # get the latest commit hash from: nix flake metadata github:astro/nix-openwrt-imagebuilder | grep -A 1 "Resolved URL" | tail -n 1
      # commit hash is will be between 'github:astro/nix-openwrt-imagebuilder/' and '?narHash=...'
      # can also clone repo and use local path instead of url if their hashes are not up to date (happens rarely), see my openwrt module for details
      # don't forget to update nixpkgs-openwrt, too
      url = "github:astro/nix-openwrt-imagebuilder/cc3db25ec5e0a64b2ef2f740d09700a1be1b99c8";
      inputs.nixpkgs.follows = "nixpkgs-openwrt";
    };

    virtualisation = {
      url = "github:shuuri-labs/nix-virtualisation";
      inputs.nixpkgs.follows = "nixpkgs-virtualisation";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs-virtualisation, ... }: let
    inherit (helper) mkNixosHost mkNixosCloudHost mkDarwinHost mkOpenWrtConfig;
    
    helper = import ./flakeHelper.nix { inherit inputs; };
  in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ]; # for flake-parts perSystem below 

      flake = {
        nixosConfigurations = {
          dondozo = mkNixosHost "dondozo" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel
            ./modules/power-saving
            ./modules/media-server
            ./modules/smb-provisioner
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/monitoring
            ./modules/paperless-ngx
            ./modules/remote-access
            ./modules/caddy
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";

          castform = mkNixosHost "castform" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel
            ./modules/power-saving
            ./modules/media-server
            ./modules/smb-provisioner
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/monitoring
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";

          missingno = mkNixosHost "missingno" [
            # ./modules/monitoring
            ./modules/homepage-dashboard
            ./modules/hdd-spindown
            ./modules/intel
            ./modules/power-saving
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/openwrt/configs/auto-deploy.nix
            ./modules/netbird/router
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";

          ludicolo = mkNixosHost "ludicolo" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel
            ./modules/power-saving
            ./modules/media-server
            ./modules/smb-provisioner
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/monitoring
            ./modules/netbird/router
            ./modules/frigate
            ./modules/caddy
            ./modules/kanidm
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";

          tatsugiri = mkNixosHost "tatsugiri" [
            # ./modules/monitoring
            ./modules/homepage-dashboard
            ./modules/hdd-spindown
            ./modules/intel
            ./modules/power-saving
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/openwrt/configs/auto-deploy.nix
            ./modules/netbird/router
            ./modules/caddy
            ./modules/remote-access
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";

          talonflame = mkNixosCloudHost "talonflame" [
            ./modules/homepage-dashboard
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";
        };
      };

      perSystem = { system, pkgs, ... }: {
        formatter = pkgs.nixpkgs-fmt;
        packages = {
          # OpenWRT Images (folder with multiple image files)

          # berlin-ap-imgs = import ./modules/openwrt/image-definitions/berlin/ap.nix { inherit inputs; };
          # london-router-imgs = import ./modules/openwrt/image-definitions/london/router.nix { inherit inputs; };

          # single image file derivation for berlin router
          # The openwrt-imagebuilder input is pinned to a specific commit in the inputs section
          # This prevents it from updating when running `nix flake update`          
          # When you want to update the OpenWRT image, update the commit hash in the inputs section
          berlin-router-img = (import ./modules/openwrt/image-definitions/builder-extractor { inherit inputs; }).mkImageExtractor {
            name = "berlin-router";
            imageDerivation = (import ./modules/openwrt/image-definitions/berlin/router.nix { inherit inputs; });
            format = "squashfs-combined-efi";
          };

          berlin-vm-router-img = (import ./modules/openwrt/image-definitions/builder-extractor { inherit inputs; }).mkImageExtractor {
            name = "berlin-vm-router";
            imageDerivation = (import ./modules/openwrt/image-definitions/berlin/vm-test-router.nix { inherit inputs; });
            format = "squashfs-combined-efi";
          };

          london-test-router-img = (import ./modules/openwrt/image-definitions/builder-extractor { inherit inputs; }).mkImageExtractor {
            name = "london-test-router";
            imageDerivation = (import ./modules/openwrt/image-definitions/london/test-router.nix { inherit inputs; });
            format = "squashfs-combined-efi";
          };

          # OpenWRT Configs
          berlin-router-config = helper.mkOpenWrtConfig "./modules/openwrt/configs/berlin/router.nix" system;
          vm-test-router-config = helper.mkOpenWrtConfig "./modules/openwrt/configs/berlin/vm-test-router.nix" system;
        };
      };
    };
}