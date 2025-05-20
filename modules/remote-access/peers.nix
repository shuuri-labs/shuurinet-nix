{ config, pkgs, lib, ... }:

let
  secretsPath = "/home/ashley/shuurinet-nix/secrets";
in
{
  config = {
    age.secrets = {
      "dondozo-wg-public-key.age".path = "${secretsPath}/dondozo-wg-public-key.age";
      "dondozo-wg-private-key.age".path = "${secretsPath}/dondozo-wg-private-key.age";

      "rotom-laptop-wg-public-key.age".path = "${secretsPath}/rotom-laptop-wg-public-key.age";
      "rotom-laptop-wg-private-key.age".path = "${secretsPath}/rotom-laptop-wg-private-key.age";
    };

    peers = {
      "dondozo" = {
        publicKeyFile = config.age.secrets."dondozo-wg-public-key.age".path;
        privateKeyFile = config.age.secrets."dondozo-wg-private-key.age".path;
        allowedIPs = [ "10.0.0.1/32" "192.168.11.0/24" ];
      };

      "rotom-laptop" = {
        publicKeyFile = config.age.secrets."rotom-laptop-wg-public-key.age".path;
        privateKeyFile = config.age.secrets."rotom-laptop-wg-private-key.age".path;
        allowedIPs = [ "10.0.0.2/32" "192.168.11.0/24" ];
      };
    };
  };
}