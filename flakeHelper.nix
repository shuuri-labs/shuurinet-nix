{ inputs }:

let
  inherit (inputs.nixpkgs.lib) nixosSystem;

  stateVersion = "25.05";

  mkHostPath = hostName: ./hosts/${hostName}/configuration.nix;

  commonModules = [
    ./homelab
    inputs.vscode-server.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
  ];

  commonmModulesHomelab = [
    # ./options-host
    # ./options-homelab
  ];

  commonConfig = { config, pkgs, inputs, stateVersion, ... }: {
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = [
      inputs.agenix.packages.${pkgs.system}.default
      inputs.home-manager.packages.${pkgs.system}.default
      pkgs.bind
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

  commonConfigHomelab = { config, pkgs, ... }: commonConfig { inherit config pkgs inputs stateVersion; } // {
    environment.systemPackages = (commonConfig { inherit config pkgs inputs stateVersion; }).environment.systemPackages ++ [
      pkgs.lm_sensors
      pkgs.python3
      pkgs.passmark-performancetest
    ];
  };

  mkNixosHost = hostName: extraModules: system:
    nixosSystem {
      inherit system;

      specialArgs = { 
        inherit inputs stateVersion mkOpenWrtConfig; 
      };
      
      modules = [
        (mkHostPath hostName)
        commonConfigHomelab
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

  mkOpenWrtConfig = { configuration, system }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    pkgs.callPackage inputs.dewclaw {
      inherit configuration;
    };

in {
  inherit mkNixosHost mkNixosCloudHost mkDarwinHost mkOpenWrtConfig;
}
