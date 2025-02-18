{ config, lib, pkgs, stateVersion, ... }:

let
  mkAddress = subnet: address: "${subnet}.${toString address}";

  mkHostNetworkContainer = { 
    name, 
    interface,
    subnet,
    address, 
    gateway ? mkAddress subnet 1,  # Default gateway is .1
    autoStart ? false,
    extraConfig ? {} 
  }: {
    inherit autoStart;

    privateNetwork = true;
    hostBridge = interface;
    localAddress = mkAddress subnet address;  # Container address

    config = { config, lib, ... }: lib.mkMerge [
      {
        system.stateVersion = stateVersion;

        networking = {
          useHostResolvConf = lib.mkForce false;
        } // lib.optionalAttrs (gateway != null) {
          defaultGateway = gateway;
          nameservers = [ gateway ];
        };
      }
      extraConfig
    ];
  };
in
{
  options.containerTemplate = {
    mkHostNetworkContainer = lib.mkOption {
      type = lib.types.anything;
      default = mkHostNetworkContainer;
      description = "Function to create a standard container configuration";
    };
  };
}