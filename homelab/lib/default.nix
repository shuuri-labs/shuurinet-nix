{ config, lib, pkgs, ... }:

{
  imports = [
    ./dashboard
    ./monitoring
    ./reverse-proxy
    ./dns
    ./domain-management
    ./vpn-confinement
    ./idp
    ./intel
    ./iperf
    ./power-saving
    ./remote-access
    ./smb
    ./uefi
    ./deployment
    ./zfs
  ];
}