{
  description = "shuurinet nix config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-virtualisation.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-openwrt.url = "github:NixOS/nixpkgs/nixos-25.05";
    
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
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
      url = "github:astro/nix-openwrt-imagebuilder/acc8d96817b38c5faf4d5c50351e2bd51b93f4b4";
      inputs.nixpkgs.follows = "nixpkgs-openwrt";
    };

    virtualisation = {
      url = "github:shuuri-labs/nix-virtualisation/version-2";
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
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";

          missingno = mkNixosHost "missingno" [
            # ./modules/monitoring
            # ./modules/homepage-dashboard
            # ./modules/hdd-spindown
            # ./modules/intel
            # ./modules/power-saving
            # ./modules/disk-care
            # ./modules/iperf
            # ./modules/uefi-boot
            # ./modules/openwrt/configs/auto-deploy.nix
            # ./modules/netbird/router
            # ./homelab
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

          misdreavus = mkNixosHost "misdreavus" [
            # ./modules/monitoring
            ./modules/homepage-dashboard
            ./modules/intel
            ./modules/power-saving
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/remote-access
            ./modules/caddy 
            inputs.vpn-confinement.nixosModules.default
            inputs.virtualisation.nixosModules.default
          ] "x86_64-linux";
        };
      };

      perSystem = { system, pkgs, ... }: {
        formatter = pkgs.nixpkgs-fmt;
        packages = {
          # OpenWRT Images (folder with multiple image files)
          
          # build the image with `nix build .#berlin-router-img`
          # berlin-ap-imgs = import ./modules/openwrt/image-definitions/berlin/ap.nix { inherit inputs; };

          bln-test-router-img = (import ./homelab/lib/openwrt/image/builder-extractor { inherit inputs; }).mkImageExtractor {
            name = "berlin-router";
            imageDefinition = (import ./hosts/missingno/openwrt-image-test.nix { inherit inputs; });
            format = "squashfs-combined-efi";
          };
        };
      };
    };
}