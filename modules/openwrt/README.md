### OpenWRT Configuration and Deployment

This module provides tools for building and deploying OpenWRT configurations and images.

## Features

- **Image Building**: Build OpenWRT images with custom configurations
- **Configuration Deployment**: Deploy configurations to OpenWRT devices
- **Auto-Deployment**: Automatically deploy configurations when derivations change using NixOS's `restartTriggers`
- **Per-Config Service Association**: Associate each configuration with its specific service

## Usage

### Building Images

Build an OpenWRT image using the flake:

```bash
nix build .#berlin-router-img --show-trace
```

### Deploying Configurations

Deploy a configuration manually:

```bash
sudo -E ./result/bin/deploy-berlin-router-config
```

### Auto-Deployment Service

Enable the auto-deployment service in your NixOS configuration:

```nix
{
  services.openwrt.auto-deploy = {
    enable = true;
    configs = {
      berlin-router-config = {
        derivation = pkgs.berlin-router-config;
        serviceName = "berlin-router"; # Optional, defaults to "network"
      };
    };
  };
}
```

The service automatically:
- Associates each configuration with its specific service
- Directly tracks the derivations using `restartTriggers`
- Detects when a derivation changes (during `nixos-rebuild switch`)
- Waits for the appropriate service to start before deploying
- Includes a 30-second delay to allow OpenWRT to fully boot
- Runs the deployment script immediately after changes

See [Auto-Deploy Service README](./services/README.md) for detailed configuration options.

### TODO: 

- auto update hashes upon build (since they change daily). currently requires a nix flake update

- image builder definitions should use host 'system' var instead of hardcoded

- config block defined in `image-defitions/berlin/router.nix` for inheritance. move up to a parent so all images can be extracted by `image-definitions/base/extract-image.nix`


