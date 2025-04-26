### TODO: 

- auto update hashes upon build (since they change daily). currently requires a nix flake update

- image builder definitions should use host 'system' var instead of hardcoded

- config block defined in `image-defitions/berlin/router.nix` for inheritance. move up to a parent so all images can be extracted by `image-definitions/base/extract-image.nix` 