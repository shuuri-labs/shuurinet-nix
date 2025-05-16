{ inputs }:

let
  inherit (inputs.nixpkgs.lib) nixosSystem;

  stateVersion = "24.11";

  mkHostPath = hostName: ./hosts/${hostName}/configuration.nix;

  commonModules = [
    ./modules/post-deployment-bootstrap
    ./modules/common
    inputs.vscode-server.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
  ];

  commonmModulesHomelab = [
    ./options-host
    ./options-homelab
  ];

  commonConfig = { config, pkgs, inputs, stateVersion, ... }: {
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = [
      inputs.agenix.packages.${pkgs.system}.default
      inputs.home-manager.packages.${pkgs.system}.default
    ];

    nixpkgs.overlays = [
      (final: prev: {
        netbird = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.netbird;
      })
    ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.ashley = import ./home.nix;
      extraSpecialArgs = { inherit stateVersion; };
    };
  };

  mkNixosHost = hostName: extraModules: system:
    nixosSystem {
      inherit system;

      specialArgs = { 
        inherit inputs stateVersion; 
      };
      
      modules = [
        (mkHostPath hostName)
        commonConfig
      ] ++ commonModules ++ commonmModulesHomelab ++ extraModules;
    };

  mkNixosCloudHost = hostName: extraModules: system:
    nixosSystem {
      inherit system;

      specialArgs = { 
        inherit inputs stateVersion; 
      };
      
      modules = [
        (mkHostPath hostName)
        commonConfig
      ] ++ commonModules ++ extraModules;
    };

  mkDarwinHost = hostName: extraModules: system:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;

      specialArgs = { 
        inherit inputs stateVersion; 
      };

      modules = [
        ./darwin/${hostName}/configuration.nix
      ] ++ extraModules;
    };

  mkOpenWrtConfig = configPath: system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    pkgs.callPackage inputs.dewclaw {
      configuration = import (builtins.path { path = ./.; name = "source"; } + "/${configPath}") { inherit inputs; };
    };

in {
  inherit mkNixosHost mkDarwinHost mkOpenWrtConfig;
}
