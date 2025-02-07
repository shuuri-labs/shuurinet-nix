inputs:
let
  mkHostPath = hostName: ./hosts/${hostName}/configuration.nix;

  nixpkgsConfig = {
    config = {
      # permit these insecure packages (used by sonarr)
      permittedInsecurePackages = [
        "aspnetcore-runtime-6.0.36"
        "aspnetcore-runtime-wrapped-6.0.36"
        "dotnet-sdk-6.0.428"
        "dotnet-sdk-wrapped-6.0.428"
      ];
      allowUnfree = true;
    };
  };

  commonConfig = { config, pkgs, inputs, ... }: {
    nixpkgs.config = nixpkgsConfig.config; # override nixpkgs config with custom config above. will append/merge, not replace.
    
    environment.systemPackages = [
      inputs.agenix.packages."${pkgs.system}".default
      inputs.home-manager.packages."${pkgs.system}".default
    ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.ashley = import ./home.nix;
    };
  };
in
{
  mkNix = hostName: extraModules: inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    
    specialArgs = {
      inherit inputs;
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
      commonConfig
    ] 
    ++ extraModules;
  };

  mkDarwin = hostName: extraModules: inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    
    specialArgs = {
      inherit inputs;
    };

    modules = [ 
      (mkHostPath hostName)
    ] 
    ++ extraModules;
  };
}