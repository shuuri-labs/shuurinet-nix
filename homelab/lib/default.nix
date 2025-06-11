{ config, lib, pkgs, ... }:

{
  imports = [
    ./networking
    ./storage
    ./disk-care
    ./dashboard
    ./reverse-proxy
    ./dns
    ./domain-management
    ./vpn-confinement
  ];
}