# Host-Specific Variables in NixOS Configuration

This document explains how to use the variables.nix approach for managing host-specific settings in your NixOS configuration.

## Overview

The `variables.nix` approach allows you to centralize host-specific settings in one file per host, making it easier to:

1. Maintain consistent configurations across hosts
2. Quickly identify and update host-specific settings
3. Reduce duplication and potential inconsistencies
4. Create new hosts with minimal effort

## Getting Started

### Creating a New Host

1. Create a new host directory in the `hosts/` folder
2. Copy `variables.nix.template` to your new host directory as `variables.nix`
3. Customize the variables for your specific host

### Using Variables in Configurations

Import the variables at the top of your configuration files:

```nix
{ ... }: let
  vars = import ../variables.nix;
in {
  # Use variables in your configuration
  networking.hostName = vars.hostName;
  time.timeZone = vars.timezone;

  # ...other configuration
}
```

## Structure of variables.nix

The `variables.nix` file contains several key sections:

### User Information

```nix
username = "olafkfreund";  # Default username
fullName = "Olaf K-Freund"; # User's full name
```

### Display Configuration

```nix
laptop_monitor = "monitor = eDP-1,1920x1080@120,0x0,1";
external_monitor = "monitor = HDMI-A-1,3840x2160@60,1920x0,1";
```

### Hardware Settings

```nix
gpu = "nvidia";  # Options: "nvidia", "amd", "intel"
acceleration = "cuda";  # Options: "cuda", "rocm", "cpu", ""
```

### System Groups

```nix
userGroups = [
  "networkmanager" "wheel" "video" "scanner" "lp"
];
```

### Networking

```nix
hostName = "hostname";
nameservers = [ "1.1.1.1" "8.8.8.8" ];
hostMappings = {
  "192.168.1.127" = "hostname1";
  "192.168.1.96" = "hostname2";
};
```

### Locale and Time

```nix
timezone = "Europe/London";
locale = "en_GB.UTF-8";
keyboardLayout = "gb";
```

### Theme Settings

```nix
theme = {
  scheme = "gruvbox-dark-medium";
  wallpaper = ./themes/wallpaper.jpg;
  # ...other theme settings
};
```

### Environment Variables

```nix
environmentVariables = {
  MOZ_ENABLE_WAYLAND = "1";
  NIXOS_WAYLAND = "1";
  # ...other environment variables
};
```

### Service-Specific Configs

```nix
services = {
  nfs = {
    enable = true;
    exports = "/shared 192.168.1.*(rw)";
  };
};
```

## Best Practices

1. **Keep It DRY**: If a variable is used in multiple files, define it once in `variables.nix`
2. **Use Meaningful Names**: Choose descriptive variable names for clarity
3. **Group Related Variables**: Keep related settings together
4. **Documentation**: Add comments for non-obvious settings
5. **Defaults**: Provide sensible defaults for optional settings

## Example Files That Use variables.nix

The following configuration files typically use variables from `variables.nix`:

- `configuration.nix` - Main system configuration
- `nixos/i18n.nix` - Locale and timezone settings
- `nixos/hosts.nix` - Network host mappings
- `nixos/envvar.nix` - Environment variables
- `themes/stylix.nix` - Theme configuration
- `nixos/screens.nix` - Monitor configuration

When adding new host-specific settings, consider whether they belong in `variables.nix` for better organization and reuse.
