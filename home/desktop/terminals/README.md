# Terminal Emulator Configurations

This directory contains configurations for various terminal emulators used in the system.

## Terminal Emulators

- `default.nix` - Main entry point that imports all terminal configurations
- `alacritty.nix` - Configuration for Alacritty, a GPU-accelerated terminal emulator
- `foot.nix` - Configuration for Foot, a lightweight Wayland terminal emulator
- `kitty.nix` - Configuration for Kitty, a feature-rich GPU-accelerated terminal
- `wezterm.nix` - Configuration for WezTerm, a GPU-accelerated cross-platform terminal

## Features

- Integration with system theme (Gruvbox)
- Custom key bindings
- Font configuration with ligatures support
- Performance optimizations
- Copy/paste behavior customization

## Usage

These terminal configurations are imported by the main terminals configuration file (`default.nix`) and then included in the desktop configuration. Each terminal can be used interchangeably, offering different features and performance characteristics depending on user preference and system capabilities.