# Hyprland Configuration

This directory contains configuration files for the Hyprland Wayland compositor.

## Structure

- `hyprland.nix` - Main entry point that imports all Hyprland configurations
- `hypr_dep.nix` - Hyprland dependencies and related packages
- `hyprlock.nix` - Screen locking configuration for Hyprland
- `hypridle.nix` - Idle management for Hyprland
- `scripts/` - Helper scripts for Hyprland
  - `packages.nix` - Script-related packages

- `config/` - Component-specific configurations
  - `autostart.nix` - Programs to launch on Hyprland startup
  - `binds.nix` - Keyboard and mouse keybindings
  - `env.nix` - Environment variables for Hyprland
  - `input.nix` - Input device configurations
  - `monitors.nix` - Monitor layout and arrangement
  - `plugins.nix` - Hyprland plugin configurations
  - `rules.nix` - Window rules and behaviors
  - `settings.nix` - General Hyprland settings
  - `workspace.nix` - Workspace configurations

## Usage

The Hyprland configuration is imported by the main desktop configuration file and then included in the user's Home Manager configuration when Hyprland is enabled as the window manager.

Hyprland provides a modern, composited Wayland experience with extensive customization options. This configuration focuses on usability, aesthetics, and performance with Gruvbox theme integration.