# Hosts Configurations

This directory contains system configurations for different machines. Each subdirectory represents a different host with its specific hardware configuration and system settings.

## Active Hosts

- `p620/` - Configuration for the P620 workstation (AMD-based system, primary development)
- `p510/` - Configuration for the P510 system (media server, includes MicroVM configurations)
- `razer/` - Configuration for the Razer laptop
- `samsung/` - Configuration for the Samsung laptop

## Offline/Archived Hosts

- `dex5550/` - **OFFLINE** - Dell Dex5550 SFF (monitoring infrastructure removed)
- `hp/` - **ARCHIVED** - HP server/workstation (decommissioned)
- `lms/` - **ARCHIVED** - LMS system (decommissioned)

## Host Directory Structure

Each host typically contains:

- `configuration.nix` - Main system configuration
- `nixos/` - NixOS-specific configurations:
  - `hardware-configuration.nix` - Generated hardware configuration
  - `boot.nix` - Boot loader configuration
  - `power.nix` - Power management settings
  - `i18n.nix` - Internationalization settings
  - `greetd.nix` - Login manager configuration
  - Other system-specific configurations
- `themes/` - Host-specific theme settings
- `services/` - Host-specific services
- `guests/` - MicroVM and container configurations (when applicable)

## Archive

- `archive/` - Historical configurations for systems no longer in active use
