# OpenWRT Auto-Deploy Service

This service automatically deploys OpenWRT configurations when their derivations change.

## Usage

Add the OpenWRT module to your NixOS configuration and enable the auto-deploy service:

```nix
{
  imports = [
    # ... other imports
    ./modules/openwrt
  ];
  
  openwrt.config-auto-deploy = {
    enable = true;
    configs = {
      berlin-router-config = {
        drv = pkgs.berlin-router-config;
        serviceName = "berlin-router"; # Optional, can be null
      };
      vm-test-router-config = {
        drv = pkgs.vm-test-router-config;
        # serviceName defaults to null
      };
    };
  };
}
```

## How it Works

1. Each configuration is defined with its derivation and an optional associated service
2. The service uses NixOS's `restartTriggers` to directly track the specified derivations
3. When a derivation changes, systemd automatically restarts the service
4. If specified, the service waits for the associated service to start before deploying
5. Each deployment includes a 30-second delay to ensure the OpenWRT system is fully booted
6. The service runs the deployment script from the derivation's bin directory as root

## Deployment Scenarios

The service handles several scenarios:

- **First-time deployment**: When you first enable the service, it runs during system activation
- **Configuration changes**: When you modify the OpenWRT configuration and rebuild, the service detects the change and redeploys
- **System reboot**: The service runs again after system reboot to ensure the configuration is applied
- **Per-config dependencies**: Each config can optionally specify which service it depends on

## Configuration Options

You can configure the auto-deploy service directly:

```nix
openwrt.config-auto-deploy = {
  # Attribute set of configurations to deploy
  configs = {
    berlin-router-config = {
      drv = pkgs.berlin-router-config;
      serviceName = "berlin-router";  # Optional, can be null
    };
  };
};
```

## Notes

- Each configuration can optionally specify which openwrt service it depends on