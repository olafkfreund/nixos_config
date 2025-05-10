# Hosts Configurations

This directory contains system configurations for different machines. Each subdirectory represents a different host with its specific hardware configuration and system settings.

## Active Hosts

- `dex5550/` - Configuration for the Dell Dex5550 laptop
- `hp/` - Configuration for the HP server/workstation
- `lms/` - Configuration for the LMS system
- `p510/` - Configuration for the P510 system (includes MicroVM configurations)
- `p620/` - Configuration for the P620 workstation (AMD-based system)
- `razer/` - Configuration for the Razer laptop

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