# Samsung Laptop Configuration

This directory contains the NixOS configuration for the Samsung laptop.

## Configuration Structure

- `configuration.nix` - Main system configuration file
- `nixos-options.nix` - System-specific option overrides
- `nixos/` - NixOS-specific configurations
  - `hardware-configuration.nix` - Generated hardware configuration
  - `boot.nix` - Boot loader and kernel configuration
  - `nvidia.nix` - NVIDIA GPU configuration
  - `power.nix` - Advanced power management settings for laptop
  - `i18n.nix` - Internationalization settings
  - `envvar.nix` - Environment variables
  - `greetd.nix` - Login manager configuration
  - `hosts.nix` - Network host entries
  - `screens.nix` - Display configuration
- `themes/` - Theme configurations

## Features

- Intel GPU
- Advanced power management for laptop battery life
- Development environment for multiple languages
- Gaming capabilities
- Optimized mobile workflow
- Modern Wayland desktop experience

## Hardware

The Razer laptop appears to have:
- Intel CPU
- Intel GPU
- High-resolution display
- SSD storage
- Good amount of RAM for development and gaming

## Usage

This configuration is used as the target for `nixos-rebuild` when deploying to the Razer laptop:

```bash
sudo nixos-rebuild switch --flake /home/olafkfreund/.config/nixos#samsung
```