# Waydroid Setup Guide

> **Complete guide for setting up Waydroid Android emulation on NixOS**

## Overview

Waydroid is a container-based approach to run a full Android system on Linux. It uses LXC containers to provide
near-native Android application performance with full Android compatibility.

## Requirements

- **Wayland Desktop Environment**: Waydroid requires Wayland (cannot run directly on X11)
- **Kernel Modules**: `binder_linux` and `ashmem_linux` (automatically configured)
- **GPU Support**: AMD (standard), NVIDIA (requires special configuration)

## Enabled Hosts

### P620 (AMD Workstation)

- **Status**:  Enabled
- **Configuration**: Standard AMD GPU configuration
- **Desktop**: COSMIC (Wayland-native) + GNOME (Wayland support)

### Razer (Intel/NVIDIA Laptop)

- **Status**: ⏸ Available (not yet enabled)
- **Configuration**: Requires `disableGbm = true` for NVIDIA GPU
- **Desktop**: COSMIC (Wayland-native) + GNOME (Wayland support)

## Post-Installation Steps

After enabling Waydroid and rebuilding your system, you **must** manually initialize Waydroid. These steps cannot be
automated in NixOS declarative configuration.

### 1. Initialize Waydroid

```bash
# Initialize Waydroid (first time only)
# This downloads Android system images (~500MB)
waydroid init

# Alternative: Initialize with Google Apps support
# waydroid init -s GAPPS -f
```

**Note**: First initialization downloads Android system images and may take 5-10 minutes depending on your connection.

### 2. Start Waydroid Session

```bash
# Start Waydroid container session
waydroid session start

# Verify session is running
waydroid status
```

### 3. Launch Waydroid UI

```bash
# Launch full Android UI
waydroid show-full-ui

# Alternative: Launch specific app
# waydroid app launch <package-name>
```

### 4. Configure Android System

Once Waydroid UI is running:

1. Complete Android initial setup wizard
2. Configure Google account (if using GAPPS variant)
3. Install applications from Play Store or via APK

## Common Commands

### System Management

```bash
# Check Waydroid status
waydroid status

# Start/stop session
waydroid session start
waydroid session stop

# Show full Android UI
waydroid show-full-ui

# Launch specific app
waydroid app launch <package-name>

# List installed apps
waydroid app list

# Install APK
waydroid app install /path/to/app.apk
```

### Advanced Configuration

```bash
# Access Waydroid container shell
sudo waydroid shell

# View Waydroid logs
journalctl -u waydroid-container -f

# Configure Waydroid properties
waydroid prop set <property> <value>

# Show current properties
waydroid prop show
```

## Google Play Store Installation

To install Google Play Store on Waydroid:

### Method 1: Initialize with GAPPS

```bash
# Stop current session
waydroid session stop

# Re-initialize with Google Apps
waydroid init -s GAPPS -f
```

### Method 2: Manual Installation

Follow the official guide:

- <https://docs.waydro.id/faq/google-play-certification>

This involves:

1. Installing Google Apps framework
2. Registering device with Google
3. Passing Play Integrity checks

## Troubleshooting

### Waydroid Won't Start

**Check if you're in a Wayland session:**

```bash
echo $XDG_SESSION_TYPE  # Should output "wayland"
```

If using X11, switch to a Wayland session or use nested Wayland:

```bash
cage waydroid show-full-ui
# or
weston --waydroid
```

### Container Service Not Running

```bash
# Check systemd services
systemctl status waydroid-container
systemctl status waydroid-mount

# Restart services
sudo systemctl restart waydroid-container
sudo systemctl restart waydroid-mount
```

### "Failed to get service waydroidplatform"

This means Waydroid hasn't been initialized:

```bash
waydroid init
waydroid session start
```

### GPU Acceleration Not Working

**NVIDIA GPUs**: Ensure `disableGbm = true` in configuration:

```nix
features.virtualization.waydroid = {
  enable = true;
  disableGbm = true;  # Required for NVIDIA
};
```

**AMD GPUs**: Standard configuration should work:

```nix
features.virtualization.waydroid = {
  enable = true;
  disableGbm = false;  # Standard for AMD
};
```

### Network Issues

Check if Android has network connectivity:

```bash
# Inside Waydroid container
sudo waydroid shell
ping 8.8.8.8

# Configure DNS if needed
waydroid prop set persist.waydroid.dns 8.8.8.8,1.1.1.1
```

## Configuration Options

### Module Options

Available in `features.virtualization.waydroid`:

```nix
features.virtualization.waydroid = {
  # Enable Waydroid Android emulation
  enable = true;

  # Disable GBM (required for NVIDIA GPUs)
  disableGbm = false;

  # Enable waydroid-helper systemd service
  enableWaydroidHelper = true;

  # Override Waydroid package
  package = pkgs.waydroid-nftables;
};
```

### Host-Specific Configuration

**P620 (AMD Workstation)**:

```nix
features.virtualization.waydroid = {
  enable = true;
  disableGbm = false;  # AMD GPU - standard config
  enableWaydroidHelper = true;
};
```

**Razer (Intel/NVIDIA Laptop)**:

```nix
features.virtualization.waydroid = {
  enable = true;
  disableGbm = true;  # NVIDIA requires GBM disablement
  enableWaydroidHelper = true;
};
```

## Storage Locations

- **Android System**: `/var/lib/waydroid/`
- **User Data**: `/home/<user>/.local/share/waydroid/`
- **Configuration**: `/etc/waydroid/`

## Performance Tips

1. **Use Wayland-native desktop**: Better performance than nested Wayland
2. **Enable GPU acceleration**: Ensure proper GPU configuration
3. **Allocate sufficient RAM**: Waydroid uses system RAM for Android
4. **Use SSD storage**: Faster app loading and system responsiveness

## Integration with Desktop

### Desktop Entry

Waydroid applications can be launched from your application menu. After installing apps:

```bash
# Create desktop entries for installed apps
waydroid app list
```

Apps will appear in your desktop's application launcher automatically.

### File Sharing

Share files between host and Waydroid:

```bash
# Host → Waydroid
cp file.txt ~/.local/share/waydroid/data/media/0/Download/

# Waydroid → Host
# Access via Android file manager, copy to /sdcard/Download/
# Files appear in ~/.local/share/waydroid/data/media/0/Download/
```

## Security Considerations

- Waydroid containers are **not** fully sandboxed from the host
- Applications have access to Android system permissions
- Network traffic is not isolated from host
- Consider security implications before running untrusted apps

## References

- [Official Waydroid Documentation](https://docs.waydro.id/)
- [NixOS Waydroid Wiki](https://wiki.nixos.org/wiki/Waydroid)
- [Waydroid GitHub Repository](https://github.com/waydroid/waydroid)
- [NixOS Discourse - Best Practices](https://discourse.nixos.org/t/waydroid-best-practices/65607)

## Support

For issues specific to:

- **Waydroid**: <https://github.com/waydroid/waydroid/issues>
- **NixOS Configuration**: <https://github.com/olafkfreund/nixos_config/issues>
- **General Questions**: <https://discourse.nixos.org/>
