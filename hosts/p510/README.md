# P510 Host Configuration

This directory contains the NixOS configuration for the P510 system, which appears to be a server/workstation with virtualization capabilities.

## Configuration Structure

- `configuration.nix` - Main system configuration file
- `nixos/` - NixOS-specific configurations
  - `hardware-configuration.nix` - Generated hardware configuration
  - `boot.nix` - Boot loader and kernel configuration
  - `nvidia.nix` - NVIDIA GPU configuration
  - `power.nix` - Power management settings
  - `i18n.nix` - Internationalization settings
  - `envvar.nix` - Environment variables
  - `greetd.nix` - Login manager configuration
  - `hosts.nix` - Network host entries
  - `mpd.nix` - Music Player Daemon configuration
  - `plex.nix` - Plex Media Server configuration
  - `microvm/` - MicroVM configurations for virtual machines
- `themes/` - Theme configurations
- `guests/` - Guest virtual machine definitions
  - `k3sserver/` - Kubernetes server node
  - `k3sagent01/` - First Kubernetes agent node
  - `k3sagent02/` - Second Kubernetes agent node

## Features

- Media server capabilities with Plex, Sonarr, Radarr, etc.
- Kubernetes cluster using K3s in MicroVMs
- NVIDIA GPU support for transcoding and compute
- Music streaming with MPD
- Development environment for container workloads

## Hardware

The P510 system appears to have:
- Intel CPU
- NVIDIA GPU
- Multiple storage volumes for media and system
- Significant RAM for virtualization workloads

## Usage

This configuration is used as the target for `nixos-rebuild` when deploying to the P510 system:

```bash
sudo nixos-rebuild switch --flake /home/olafkfreund/.config/nixos#p510
```