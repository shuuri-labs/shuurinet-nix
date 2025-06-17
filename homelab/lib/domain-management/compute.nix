# Domain utility functions for homelab services

{
  computeFQDN = { topLevel, sub, base }:
    if sub != null then
      "${topLevel}.${sub}.${base}"
    else
      "${topLevel}.${base}";
} 