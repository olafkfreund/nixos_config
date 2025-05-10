# P620 Host Configuration

This directory contains the NixOS configuration for the P620 workstation, which is an AMD-based system.

## Configuration Structure

- `configuration.nix` - Main system configuration file
- `nixos-options.nix` - System-specific option overrides
- `nixos/` - NixOS-specific configurations
  - `hardware-configuration.nix` - Generated hardware configuration
  - `boot.nix` - Boot loader and kernel configuration
  - `amd.nix` - AMD GPU and CPU configuration
  - `power.nix` - Power management settings
  - `i18n.nix` - Internationalization settings
  - `envvar.nix` - Environment variables
  - `greetd.nix` - Login manager configuration
  - `hosts.nix` - Network host entries
  - `mpd.nix` - Music Player Daemon configuration
  - `screens.nix` - Display configuration
  - `syncthing.nix` - Syncthing file synchronization configuration
  - `env.nix` - Environment variables for Hyprland/Wayland
- `themes/` - Theme configurations

## Features

- AMD CPU and GPU support with optimizations
- Development environment for multiple languages
- Gaming capabilities
- Media playback
- File synchronization with Syncthing
- Modern desktop experience with Wayland

## Hardware

The P620 system has:
- AMD CPU (Ryzen)
- AMD GPU
- Multiple storage volumes including dedicated game storage
- High-performance components

## Usage

This configuration is used as the target for `nixos-rebuild` when deploying to the P620 system:

```bash
sudo nixos-rebuild switch --flake /home/olafkfreund/.config/nixos#p620
```