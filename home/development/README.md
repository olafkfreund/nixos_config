# Development Environment Configuration

This directory contains configurations for development tools and environments managed through Home Manager.

## Components

- `containers.nix` - Container development environment configurations
- `cursor-code.nix` - Cursor editor configuration
- `default.nix` - Main entry point that imports all development configurations
- `distrobox.nix` - Distrobox container configurations for different Linux distributions
- `nvim.nix` - Neovim editor configuration
- `vscode.nix` - Visual Studio Code configuration with extensions and settings
- `windsurf.nix` - Windsurf Nix development tool configuration
- `zed.nix` - Zed editor configuration

## Usage

These configurations are imported by the main development configuration file (`default.nix`) and then included in the user's Home Manager configuration. Each development tool typically includes:

- Package installation
- Plugin/extension configurations
- Editor themes and appearance settings
- Language-specific configurations
- Integration with language servers

The development configurations can be selectively enabled in user configurations based on the specific needs of each system.
