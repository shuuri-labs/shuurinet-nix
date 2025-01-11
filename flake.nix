{
  description = "Nixos config flake";

  inputs = {
    # core nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager for user configurations
    home-manager.url = "github:nix-community/home-manager";

    # vscode server module for nixos 
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    # MacOS 
    nix-darwin.url = "github:LnL7/nix-darwin";

    # Agenix for managing secrets
    agenix.url = "github:ryantm/agenix";

    # Service-level VPN confinement
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

    # secrets.url = "path:/home/ashley/shuurinet-nix/secrets";
  };

  outputs = { self, nixpkgs, vscode-server, home-manager, nix-darwin, agenix, vpn-confinement, ... }:
    let
      system = "x86_64-linux";

      # Helper function to create a NixOS configuration for a host
      makeHost = hostPath: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./options-host
          ./options-homelab
          ./modules/common
          # ./modules/users-groups
          #  ({ ... }: {
          #   _module.args.secretsPath = ./secrets;
          # })
          vpn-confinement.nixosModules.default
          vscode-server.nixosModules.default
          agenix.nixosModules.default
          hostPath                 # Host-specific configuration.nix
          ({ config, pkgs, inputs, ... }: {
            environment.systemPackages = [
              agenix.packages."${system}".default
            ];
          })
        ];
      };
    in {
      # NixOS configurations for various hosts
      nixosConfigurations = {
        "dondozo" = makeHost ./hosts/dondozo/configuration.nix;
        "nixos" = makeHost ./hosts/lotad/configuration.nix;
        "lotad" = makeHost ./hosts/lotad/configuration.nix;
        "castform" = makeHost ./hosts/castform/new-config.nix;
      };
    
      # MacOS configuration via nix-darwin
    #   darwinConfigurations."rotom" = nix-darwin.lib.darwinSystem {
    #   system = "arm64-darwin";
    #   modules = [
    #       ./hosts/rotom/darwin-configuration.nix
    #       home-manager.nixosModules.home-manager
    #   ];
    #   };
    };
}
