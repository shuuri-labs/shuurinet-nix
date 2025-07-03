{ config, lib, ... }:
let
  buildConfig = { name, config, ... }: 
  {
    openwrt.${name} = config;
  }
in
{
  inherit buildConfig;
}