# User Configurations

This directory contains user-specific Home Manager configurations that define the user environment for different hosts.

## Structure

- `olafkfreund/` - Configurations for the `olafkfreund` user across different systems
  - `private.nix` - Private user settings (personal Git configuration, etc.)
  - `razer_home.nix` - User configuration for the Razer laptop
  - `p620_home.nix` - User configuration for the P620 workstation
  - `p510_home.nix` - User configuration for the P510 system

## Usage

These user configurations are imported by the host configurations in `flake.nix` through the Home
Manager module. Each user configuration imports relevant modules from the `home/` directory to
define the user's environment.

The user configurations typically include:

- Theme settings (colorscheme)
- User-specific path and environment variables
- Shell preferences
- Desktop environment customizations
- Application preferences

Each host-specific user configuration (`*_home.nix`) is tailored to the specific hardware and use case of that system.
