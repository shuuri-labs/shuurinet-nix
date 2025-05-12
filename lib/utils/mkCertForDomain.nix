{ pkgs, lib, ... }:
let
  mkCertForDomain = (name: domain: pkgs.runCommand "cert-${name}" { } ''
    HOME=$TMPDIR
    ${pkgs.mkcert}/bin/mkcert -install
    ${pkgs.mkcert}/bin/mkcert \
      -cert-file ${name}.pem \
      -key-file  ${name}-key.pem \
      "${domain}" "127.0.0.1"
    mkdir -p $out
    cp ${name}.pem ${name}-key.pem $out/
    cp $HOME/.local/share/mkcert/rootCA.pem $out/ca.pem
  '');
in
{
  inherit mkCertForDomain;
}