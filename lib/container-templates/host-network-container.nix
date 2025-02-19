{ config, lib, pkgs, stateVersion, ... }:

let
  mkAddress = subnet: address: "${subnet}.${toString address}";

  base = { 
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
    localAddress = "${mkAddress subnet address}/24";

    config = { config, lib, pkgs, ... }: lib.mkMerge [
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
  inherit base;
}