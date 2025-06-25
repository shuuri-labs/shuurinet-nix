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
  
  # Function to create both config and image
  mkApImage = args:
    let
      config = mkApConfig args;
      image = inputs.openwrt-imagebuilder.lib.build config;
    in
      image // { inherit config; };
in 
{
  inherit mkApConfig mkApImage;
}