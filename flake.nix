{
  description = "shuurinet nixos config flake";

  nixConfig = {
    trusted-substituters = [
      "https://cachix.cachix.org"
      "https://nixpkgs.cachix.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11"; # update flakeHelper.nix stateVersion to match
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # nix-darwin = {
    #   url = "github:LnL7/nix-darwin";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
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

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    openwrt-imagebuilder.url = "github:astro/nix-openwrt-imagebuilder";

    dewclaw.url = "github:MakiseKurisu/dewclaw";
    
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      
      flake = {
        nixosConfigurations = let
          helper = import ./flakeHelper.nix inputs;
          inherit (helper) mkNix mkDarwin mkOpenWrtHosts;
        in {
          "dondozo" = mkNix "dondozo" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel-graphics
            ./modules/power-saving
            ./modules/virtualization
            ./modules/media-server
            ./modules/smb-provisioner
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/monitoring
            ./modules/paperless-ngx
            inputs.vpn-confinement.nixosModules.default
          ];

          "castform" = mkNix "castform" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel-graphics
            ./modules/power-saving
            ./modules/virtualization
            ./modules/media-server
            ./modules/smb-provisioner
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/monitoring
            inputs.vpn-confinement.nixosModules.default
          ];

          "ludicolo" = mkNix "ludicolo" [
            ./modules/homepage-dashboard
            ./modules/zfs
            ./modules/hdd-spindown
            ./modules/intel-graphics
            ./modules/power-saving
            ./modules/virtualization
            ./modules/media-server
            ./modules/smb-provisioner
            ./modules/disk-care
            ./modules/iperf
            ./modules/uefi-boot
            ./modules/monitoring
            ./modules/netbird/router
            ./modules/frigate
            inputs.vpn-confinement.nixosModules.default
          ];
        };
      };

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        formatter = pkgs.nixpkgs-fmt;
        
        packages = {
          berlin-router-img = (import ./modules/openwrt/image-definitions/berlin/router.nix) { inherit inputs; };
          berlin-ap-img = (import ./modules/openwrt/image-definitions/berlin/ap.nix) { inherit inputs; };
          london-router-img = (import ./modules/openwrt/image-definitions/london/router.nix) { inherit inputs; };
        } // 
        (import ./modules/openwrt/image-builder-definitions.nix { inherit inputs; }) //
        (let
          helper = import ./flakeHelper.nix inputs;
        in helper.mkOpenWrtHosts system);
      };
    };
}
