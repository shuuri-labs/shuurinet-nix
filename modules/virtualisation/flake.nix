{
  description = "Virtualisation module with pinned QEMU version";

  inputs = {
    # Pin nixpkgs to a specific version to prevent QEMU updates
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11"; # Choose a stable version
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages = {
          qemu = pkgs.qemu;
          libvirt = pkgs.libvirt;
          spice-gtk = pkgs.spice-gtk;
          OVMFFull = pkgs.OVMFFull;
        };
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          # Use the pinned versions from this flake instead of the host system's nixpkgs
          vPkgs = self.packages.${pkgs.system};
        in {
          imports = [ ./default.nix ];

          config = lib.mkIf config.virtualisation.base.enable {
            environment.systemPackages = [
              vPkgs.qemu
              vPkgs.libvirt
              vPkgs.spice-gtk
            ];
            
            virtualisation.libvirtd.qemu.ovmf.packages = [ vPkgs.OVMFFull.fd ];
          };
        };
    };
} 