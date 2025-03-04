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
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ ... }:
    let
      helper = import ./flakeHelper.nix inputs;
      inherit (helper) mkNix mkDarwin;
    in {
      nixosConfigurations = {
        "dondozo" = mkNix "dondozo" [
          ./modules/homepage-dashboard
          ./modules/zfs
          ./modules/hdd-spindown
          ./modules/intel-graphics
          ./modules/power-saving
          ./modules/intel-virtualization
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
          ./modules/intel-virtualization
          ./modules/media-server
          ./modules/smb-provisioner
          ./modules/disk-care
          ./modules/iperf
          ./modules/uefi-boot
          ./modules/monitoring
          inputs.vpn-confinement.nixosModules.default
          inputs.nixvirt.nixosModules.default
        ];

        "ludicolo" = mkNix "ludicolo" [
          ./modules/homepage-dashboard
          ./modules/zfs
          ./modules/hdd-spindown
          ./modules/intel-graphics
          ./modules/power-saving
          ./modules/intel-virtualization
          ./modules/media-server
          ./modules/smb-provisioner
          ./modules/disk-care
          ./modules/iperf
          ./modules/uefi-boot
          ./modules/monitoring
          ./modules/netbird/router
          ./modules/frigate
          inputs.vpn-confinement.nixosModules.default
          inputs.nixvirt.nixosModules.default
        ];
      };
    };
}
