# Hyprland Configuration

A comprehensive, modular Hyprland configuration built with NixOS and Home Manager, featuring modern Wayland compositor setup with extensive customization and optimization.

## Overview

This Hyprland configuration has been extensively refactored and enhanced with a comprehensive feature system including **native Nix attributes**, **feature flags**, **performance profiles**, **centralized theming**, **intelligent rule generation**, **advanced workspace management**, and **configuration validation**. The system provides better type safety, maintainability, and IDE support while offering unprecedented customization capabilities.

## Architecture

### Directory Structure

```
hyprland/
├── README.md                    # This file - comprehensive documentation
├── hyprland.nix                # Main entry point and module imports
├── hypr_dep.nix                # Dependencies and related packages
├── hyprlock.nix                # Screen locking configuration
├── hypridle.nix                # Idle management configuration
├── scripts/                    # Helper scripts and utilities
│   └── packages.nix            # Script-related packages
└── config/                     # Core configuration modules
    ├── autostart.nix           # Startup applications
    ├── binds.nix               # Keybindings and shortcuts
    ├── env.nix                 # Environment variables
    ├── input.nix               # Input device configuration
    ├── layerrules.nix          # Layer rules for overlays
    ├── monitors.nix            # Monitor configuration (host-specific)
    ├── plugins.nix             # Hyprland plugins
    ├── rules.nix               # Window rules and behaviors
    ├── settings.nix            # Core Hyprland settings
    └── workspace.nix           # Workspace configuration
```

### Configuration Philosophy

1. **Native Nix Configuration**: All settings use proper Nix attributes instead of string interpolation
2. **Modular Design**: Each component is in its own file for maintainability
3. **Type Safety**: Leverages Nix's type system for better error detection
4. **Feature Flags**: Granular control over enabled components and features
5. **Performance Profiles**: Hardware-aware optimization for different system capabilities
6. **Centralized Theming**: Consistent styling across all Hyprland components
7. **Intelligent Rules**: Automated window rule generation for common patterns
8. **Advanced Workspace Management**: Multi-monitor aware workspace distribution
9. **Configuration Validation**: Comprehensive validation framework with error checking
10. **Host-Specific Flexibility**: Automatic adaptation to different hardware configurations

## Core Components

### 1. Settings (`config/settings.nix`)

**Purpose**: Core Hyprland compositor settings including animations, layouts, and visual effects.

**Key Features**:
- Optimized animation curves with Material Design 3 beziers
- Performance-tuned blur and shadow effects
- Multiple layout support (master/dwindle)
- Gesture configuration for touchpad devices
- VRR (Variable Refresh Rate) support

**Important Settings**:
```nix
# Performance optimizations
misc.vrr = 1;                    # Adaptive sync
decoration.blur.passes = 4;      # Reduced from 6 for better performance
animations.enabled = true;       # Smooth animations with optimized timing
```

### 2. Window Rules (`config/rules.nix`)

**Purpose**: Comprehensive window management rules for various applications.

**Organization**:
- **Terminal Emulators**: Consistent floating behavior (1000x1000)
- **System Utilities**: Bluetooth, network, sound controls
- **Productivity Apps**: Thunderbird with detailed dialog handling
- **Communication**: Discord, Slack, Telegram workspace assignments
- **Entertainment**: Spotify special workspace
- **Gaming**: Immediate mode for reduced input latency
- **Screen Sharing**: XWayland video bridge compatibility

**Special Workspaces**:
- `special:magic` - 1Password
- `special:chrome` - Google Chrome
- `special:mail` - Thunderbird
- `special:discord` - Discord/Vesktop
- `special:slack` - Slack
- `special:spotify` - Music player

### 3. Keybindings (`config/binds.nix`)

**Purpose**: Comprehensive keyboard and mouse shortcuts for efficient workflow.

**Layout**: Vim-style navigation with SUPER as main modifier

**Key Categories**:
- **Window Navigation**: `SUPER + h/j/k/l` for focus movement
- **Workspace Switching**: `SUPER + 1-0` for workspace numbers
- **Window Management**: `SUPER + Q` (kill), `SUPER + F` (fullscreen)
- **Application Launchers**: `SUPER + RETURN` (terminal), `SUPER + SPACE` (rofi)
- **Special Workspaces**: `SUPER + S/B/M/D` for different special areas
- **Layout Control**: `SUPER + Y/U` for dwindle/master layouts
- **System Controls**: Volume, brightness, screenshots

**Resize Mode**: `SUPER + R` enters resize mode with vim-style controls

### 4. Environment Variables (`config/env.nix`)

**Purpose**: Configure environment variables for optimal Wayland integration.

**Categories**:
- **System Defaults**: Editor (nvim), browser (chrome), terminal (foot)
- **Wayland Integration**: Session type, desktop environment
- **Application Support**: Kitty, Firefox, Qt, GTK configuration
- **Graphics**: Cursor themes, platform backends
- **NVIDIA Support**: Commented out but ready for NVIDIA GPUs

### 5. Monitor Configuration (`config/monitors.nix`)

**Purpose**: Host-specific monitor setup using dynamic configuration.

**Features**:
- Imports monitor settings from host variables
- Supports laptop + external monitor configurations
- Uses string interpolation for dynamic setup
- Host-specific in `/hosts/*/variables.nix`

## Installation and Setup

### Prerequisites

- NixOS with flakes enabled
- Home Manager configured
- Hyprland available in nixpkgs

### Integration

The configuration is designed to be imported by your main desktop configuration:

```nix
# In your home-manager configuration
imports = [
  ./home/desktop/hyprland
];

# Enable Hyprland
wayland.windowManager.hyprland.enable = true;
```

### Host-Specific Configuration

Monitor configuration is managed per-host in `/hosts/*/variables.nix`:

```nix
# Example host configuration
laptop_monitor = "monitor=eDP-1,1920x1080@60,0x0,1";
external_monitor = "monitor=DP-1,2560x1440@144,1920x0,1";
```

## Customization Guide

### Adding New Applications

1. **Window Rules** (`config/rules.nix`):
```nix
# Add to windowrulev2 array
"float, class:(your-app)"
"size 800 600, class:(your-app)"
"workspace special:your-workspace, class:(your-app)"
```

2. **Keybindings** (`config/binds.nix`):
```nix
# Add to bind array
"$mainMod, X, exec, your-application"
"$mainMod, Y, togglespecialworkspace, your-workspace"
```

### Performance Tuning

For different hardware capabilities, adjust these settings in `config/settings.nix`:

**High-end systems**:
```nix
decoration.blur.passes = 6;        # More blur passes
animations.enabled = true;         # Full animations
misc.vrr = 1;                     # Variable refresh rate
```

**Lower-end systems**:
```nix
decoration.blur.passes = 2;        # Fewer blur passes
decoration.blur.enabled = false;   # Disable blur entirely
animations.enabled = false;        # Disable animations
```

### Theme Customization

1. **Colors** (`config/settings.nix`):
```nix
general."col.active_border" = "rgb(your-color)";
general."col.inactive_border" = "rgb(your-color)";
```

2. **Cursor Theme** (`config/env.nix`):
```nix
"XCURSOR_THEME,Your-Cursor-Theme"
"GTK_THEME,Your-GTK-Theme"
```

## Maintenance and Updates

### Regular Maintenance Tasks

1. **Monitor Performance**:
   - Check system resources with `htop`
   - Monitor Hyprland logs: `journalctl -f -u hyprland`
   - Adjust blur/animation settings if needed

2. **Update Keybindings**:
   - Review and clean unused bindings
   - Add new application shortcuts as needed
   - Document custom keybindings

3. **Window Rules Cleanup**:
   - Remove rules for uninstalled applications
   - Optimize frequently used application rules
   - Test special workspace assignments

### Adding New Features

1. **New Plugins** (`config/plugins.nix`):
   - Add plugin configuration
   - Update dependencies in `hypr_dep.nix`
   - Test compatibility

2. **New Workspaces**:
   - Add special workspace rules
   - Create corresponding keybindings
   - Update documentation

### Troubleshooting

**Common Issues**:

1. **Applications not following rules**:
   - Check class names: `hyprctl clients`
   - Verify rule syntax
   - Test with simple rules first

2. **Performance issues**:
   - Reduce blur passes
   - Disable animations temporarily
   - Check GPU driver compatibility

3. **Keybinding conflicts**:
   - Review all bindings for duplicates
   - Use `hyprctl binds` to list active bindings
   - Test individual bindings

## Advanced Configuration

### Multi-Monitor Setup

For complex monitor arrangements, edit your host's `variables.nix`:

```nix
laptop_monitor = "monitor=eDP-1,1920x1080@60,0x1440,1";
external_monitor = "monitor=DP-1,2560x1440@144,0x0,1";
# Position laptop screen below external monitor
```

### Gaming Optimizations

Enable immediate mode for specific games in `config/rules.nix`:

```nix
# Add to windowrulev2 array
"immediate, class:^(your-game)$"
"workspace 5, class:^(your-game)$"  # Dedicated gaming workspace
```

### Development Workflow

For development-focused setup:

1. **IDE Integration**:
```nix
# In rules.nix
"workspace 2, class:^(code)$"        # VS Code on workspace 2
"workspace 3, class:^(jetbrains-)$"  # JetBrains IDEs on workspace 3
```

2. **Terminal Management**:
```nix
# In binds.nix  
"$mainMod, grave, togglespecialworkspace, terminal"  # Quick terminal access
```

## Migration from String Configuration

If migrating from old string-based configuration:

1. **Identify Settings**: Extract settings from `extraConfig` strings
2. **Convert Format**: Transform to Nix attribute syntax
3. **Test Incrementally**: Convert one file at a time
4. **Validate**: Ensure all features still work

**Example Migration**:
```nix
# Old format
extraConfig = ''
  general {
    gaps_in = 2
    gaps_out = 2
  }
'';

# New format
settings = {
  general = {
    gaps_in = 2;
    gaps_out = 2;
  };
};
```

## Contributing

When contributing to this configuration:

1. **Follow Conventions**:
   - Use native Nix attributes where possible
   - Keep modules focused and single-purpose
   - Add comments for complex configurations

2. **Testing**:
   - Test on multiple hardware configurations
   - Verify backward compatibility
   - Check performance impact

3. **Documentation**:
   - Update this README for new features
   - Add inline comments for complex rules
   - Document any breaking changes

## Resources

- **Hyprland Wiki**: https://wiki.hyprland.org/
- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **Home Manager**: https://nix-community.github.io/home-manager/
- **Configuration Examples**: Check other files in this repository

---

This configuration represents a modern, maintainable approach to Hyprland setup with NixOS. The native Nix attribute usage provides better type safety and IDE support while maintaining the full power and flexibility of Hyprland's configuration system.