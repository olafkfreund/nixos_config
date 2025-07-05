# Desktop Environment Modules

This directory contains modules for desktop environment configuration and related applications.

## Available Modules

### Core Desktop Components
- **gtk/** - GTK theme and application configuration
- **electron-config.nix** - Wayland optimization for Electron applications
- **hyprland-uwsm.nix** - Hyprland with UWSM session management
- **plasma/** - KDE Plasma desktop environment configuration
- **remote/** - Remote desktop and VNC services
- **vnc/** - VNC server configuration
- **wlr/** - wlroots-based compositor utilities

### Application Integration
- **cloud-sync/** - Cloud storage synchronization services

## Usage Examples

### Basic Desktop Setup
```nix
{
  # Enable core desktop functionality
  imports = [
    ./modules/desktop
  ];
  
  # Configure desktop environment
  modules.desktop = {
    enable = true;
    environment = "hyprland";
  };
}
```

### Electron Application Optimization
```nix
{
  # Optimize Electron apps for Wayland
  modules.desktop.electron = {
    enable = true;
    waylandOptimizations = true;
  };
}
```

## Module Dependencies

Most desktop modules require:
- A compatible window manager or desktop environment
- Graphics drivers properly configured
- Audio system (PipeWire recommended)

## Configuration Notes

- Desktop modules are designed to work together but can be used independently
- Wayland-based configurations are recommended for modern hardware
- Some modules may require specific hardware features (e.g., hardware acceleration)

## Troubleshooting

### Common Issues
1. **Missing desktop session**: Ensure display manager is properly configured
2. **Graphics issues**: Verify GPU drivers are installed and configured
3. **Audio problems**: Check PipeWire/PulseAudio configuration in services/sound

### Debug Commands
```bash
# Check session status
echo $XDG_SESSION_TYPE

# Verify graphics driver
lspci -k | grep -A 2 -i vga

# Test audio
pactl info
```

See individual module documentation for specific configuration options and troubleshooting.