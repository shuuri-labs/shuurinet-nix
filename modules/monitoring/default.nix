{ config, ... }:

{
  imports = [
    ./prometheus.nix
    ./grafana.nix
    ./uptime-kuma.nix
  ];
}