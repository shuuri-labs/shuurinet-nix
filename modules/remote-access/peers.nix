{ config, pkgs, lib, ... }:

{
  peers = {
    "dondozo" = {
      publicKeyFile = config.age.secrets.dondozo-public-key.path;
      privateKeyFile = config.age.secrets.dondozo-private-key.path;
      allowedIPs = [ "10.0.0.1/32" "192.168.11.0/24" ];
    };

    "rotom-laptop" = {
      publicKeyFile = config.age.secrets.rotom-laptop-public-key.path;
      privateKeyFile = config.age.secrets.rotom-laptop-private-key.path;
      allowedIPs = [ "10.0.0.2/32" "192.168.11.0/24" ];
    };
  };
}