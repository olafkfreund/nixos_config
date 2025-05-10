# Sway Configuration

This directory contains configuration files for the Sway Wayland compositor, a tiling window manager that's compatible with i3 configuration.

## Structure

- `default.nix` - Main entry point for Sway configuration
- `swayosd.nix` - On-screen display notifications for Sway
- `config/` - Component-specific configurations

## Features

- Customized keybindings for common window management tasks
- Integration with system theme (Gruvbox)
- Media key support with swayosd
- Workspace management
- Automatic screen locking

## Usage

This configuration is imported by the user's Home Manager configuration when Sway is enabled as the window manager. It provides a lightweight but powerful window management experience with strong keyboard-driven controls.

Sway works well on systems where compatibility with the i3 workflow is desired but with modern Wayland features.