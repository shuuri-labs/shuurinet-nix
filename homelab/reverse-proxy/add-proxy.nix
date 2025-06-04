{ 
  domain, 
  address ? "127.0.0.1", 
  port 
}:
{
  services.caddy.virtualHosts = {
    "${domain}" = {
      extraConfig = ''
        reverse_proxy ${address}:${toString port}
      '';
    };
  };
}