{ inputs }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  
  base = import ./base.nix { inherit inputs; };

  mkApConfig = args@{ 
    disabledServices ? [ "dnsmasq" "odhcpd" ],
    ...
  }: base.mkBaseConfig (args // {
    inherit disabledServices;
  });
in {
  inherit mkApConfig;
}