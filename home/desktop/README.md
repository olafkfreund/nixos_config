# Desktop Environment Configuration

This directory contains configurations for desktop environments, window managers, and related utilities managed through Home Manager.

## Components

- `ags/` - Configuration for AGS (Aylur's GTK Shell)
- `com.nix` - Common desktop utilities and settings
- `default.nix` - Main entry point that imports all desktop configurations
- `default-servers.nix` - Server-specific desktop configurations
- `dbus.nix` - D-Bus session configuration
- `dunst/` - Notification daemon configuration
- `evince/` - Document viewer configuration
- `file-associations.nix` - Default application associations
- `flameshot/` - Screenshot tool configuration
- `gaming/` - Gaming-related desktop utilities
- `git-sync/` - Git synchronization utilities
- `hyprland/` - Hyprland window manager configuration
- `kdeconnect/` - KDE Connect for device integration
- `kooha/` - Screen recording tool configuration
- `lanmouse/` - LAN mouse sharing configuration
- `mail/` - Mail client configurations
- `neofetch/` - System information tool configuration
- `obs/` - Open Broadcaster Software configuration
- `plasma/` - KDE Plasma desktop environment configuration
- `remotedesktop/` - Remote desktop utilities
- `rofi/` - Application launcher configuration
- `slack/` - Slack desktop client configuration
- `sound/` - Audio configuration utilities
- `sway/` - Sway window manager configuration
- `swaylock/` - Screen locker for Wayland
- `swaync/` - Notification center for Sway
- `terminals/` - Terminal emulator configurations
- `theme/` - Desktop theme configurations
- `thunderbird/` - Email client configuration
- `walker/` - Walker launcher configuration
- `waybar/` - Status bar for Wayland
- `waypipe/` - Remote application forwarding
- `zathura/` - Document viewer configuration

## Usage

These configurations are imported by the main desktop configuration file (`default.nix`) and then included in the user's Home Manager configuration. Each component typically includes:

- Package installation
- Configuration files
- Keybindings (for window managers)
- Theme integration