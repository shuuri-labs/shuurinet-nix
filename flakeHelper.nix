inputs:
let
  mkHostPath = hostName: ./hosts/${hostName}/configuration.nix;

  mkOpenWrt = configPath: system: 
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    pkgs.callPackage inputs.dewclaw {
      configuration = import (./. + configPath);
    };

  commonConfig = { config, pkgs, inputs, stateVersion, ... }: {
    nixpkgs.config.allowUnfree = true;
    
    environment.systemPackages = [
      inputs.agenix.packages."${pkgs.system}".default
      inputs.home-manager.packages."${pkgs.system}".default
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

  stateVersion = "24.11";
in
{
  mkNix = hostName: extraModules: inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    
    specialArgs = {
      inherit inputs;
      stateVersion = stateVersion;
    };

    modules = [
      (mkHostPath hostName)
      ./modules/common
      ./options-host
      ./options-homelab
      inputs.vscode-server.nixosModules.default
      inputs.agenix.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.nixvirt.nixosModules.default
      commonConfig
    ] 
    ++ extraModules;
  };

  mkDarwin = hostName: extraModules: inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    
    specialArgs = {
      inherit inputs;
      stateVersion = stateVersion;
    };

    modules = [ 
      (mkHostPath hostName)
    ] 
    ++ extraModules;
  };

  mkOpenWrtHosts = system: {
    default = mkOpenWrt "/modules/openwrt/configs/vm-test-router.nix" system;
    berlin-router = mkOpenWrt "/modules/openwrt/configs/berlin-router.nix" system;
    vm-test-router = mkOpenWrt "/modules/openwrt/configs/vm-test-router.nix" system;  
  };
}