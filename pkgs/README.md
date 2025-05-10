# Custom Packages

This directory contains custom package definitions that aren't available in nixpkgs or require modifications from the standard packages.

## Package List

- `aider-chat-env/` - Environment configuration for aider chat
- `msty/` - Custom msty package
- `rofi-blocks/` - Custom rofi-blocks implementation

## Usage

These packages are made available to the system through an overlay defined in `flake.nix`. The main entry point is `default.nix`, which exposes all custom packages.

To add a new package:

1. Create a new directory for your package with appropriate build files
2. Add an entry in `default.nix` to expose the package

The custom packages can then be referenced in system configurations using `pkgs.customPkgs.<package-name>`.