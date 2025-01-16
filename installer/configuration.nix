   { config, pkgs, ... }:

   {
     imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> ];

     users.users.root = {
       openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1TmZx5UfPLkQd583pbMNtlLiq2bH8vnNseYY23zDAdsQDrK5B2oLXFZVHaDeEvg592mUtCxGMXZUaSULizEntyQ82Uszel6aj33Lr3IvEH11eRBv6DjfFZ1SyYRPBqjvh/p4tSRZuqjQ/ZUH52minKCcRouDt978rhSnyIb3Q69CJjn0mBC4JIhXXxueOeKUDagRnieBGlh51VEFSw7nFH+UVep2bEKg3bNgKPBj1J9rWgnp0HB8IGwGuXH0AOyH0CKTUXkhiFbewX5ONCZwdRbvbtp3JE0W7/m4WKHuDN88+yPIAxPqrm9qZFdhiyzrY2Nc/+gO9Y/stApxEID9lcRihgKc1KYJiiLKsmB4fbkuvqXKZRoUIymId0KFCnnHPQUTNjpgy/6Hzfz0TINoS/4CR2uTaO5cUuCqYvPia/ksgeZVMKxGdKZ3CokUDRbHOMREWyqXaooHFv5BjM36UIIv5vyYxViwbfXcuVW3tmsKaUIrr2NYzmtzsN0PSZV0= ashleyamohmensah@Ashleys-MacBook-Pro.local"
       ];
     };
   }