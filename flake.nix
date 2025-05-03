{
  description = "shuurinet nix config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

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
      url = "github:astro/nix-openwrt-imagebuilder";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # do not follow nixpkgs for virtualisation! use pinned nixpkgs from its own flake
    virtualisation = {
      url = "path:./modules/virtualisation";
    };
  };

  outputs = inputs@{ flake-parts, ... }: let
    helper = import ./flakeHelper.nix { inherit inputs; };
    inherit (helper) mkNixosHost mkDarwinHost mkOpenWrtConfig;
  in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ]; # for flake-parts perSystem below 

      flake = {
        nixosConfigurations = {
          dondozo = mkNixosHost "dondozo" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel-graphics
            ./modules/power-saving
            ./modules/media-server
            ./modules/smb-provisioner
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/monitoring
            ./modules/paperless-ngx
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";

          castform = mkNixosHost "castform" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel-graphics
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
            ./modules/homepage-dashboard
            ./modules/hdd-spindown
            ./modules/intel-graphics
            ./modules/power-saving
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/openwrt/configs/auto-deploy.nix
            # ./modules/monitoring
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";

          ludicolo = mkNixosHost "ludicolo" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel-graphics
            ./modules/power-saving
            ./modules/media-server
            ./modules/smb-provisioner
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/monitoring
            ./modules/netbird/router
            ./modules/frigate
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";
        };

        tatsugiri = mkNixosHost "tatsugiri" [
          ./modules/uefi-boot
          ./modules/virtualisation
          ./modules/power-saving
          ./modules/intel-graphics
          ./modules/disk-care

          ./modules/openwrt
          ./modules/netbird/router
          
          ./modules/homepage-dashboard
          ./modules/iperf
          ./modules/monitoring
        ] "x86_64-linux";
      };

      perSystem = { system, pkgs, ... }: {
        formatter = pkgs.nixpkgs-fmt;
        packages = {
          # OpenWRT Images (folder with multiple image files)

          # berlin-ap-imgs = import ./modules/openwrt/image-definitions/berlin/ap.nix { inherit inputs; };
          # london-router-imgs = import ./modules/openwrt/image-definitions/london/router.nix { inherit inputs; };

          # single image file derivation for berlin router
          berlin-router-img = (import ./modules/openwrt/image-definitions/base/extract-image.nix { inherit inputs; }).mkImageExtractor {
            name = "berlin-router";
            imageDerivation = (import ./modules/openwrt/image-definitions/berlin/router.nix { inherit inputs; });
            format = "squashfs-combined-efi";
          };

          # OpenWRT Configs
          berlin-router-config = helper.mkOpenWrtConfig "/modules/openwrt/configs/berlin/router.nix" system;
          vm-test-router-config = helper.mkOpenWrtConfig "/modules/openwrt/configs/berlin/vm-test-router.nix" system;
        };
      };
    };
}
