# Browser Configurations

This directory contains configurations for various web browsers managed through Home Manager.

## Available Browsers

- `brave.nix` - Configuration for Brave Browser
- `chrome.nix` - Configuration for Google Chrome
- `default.nix` - Main entry point that imports all browser configurations
- `firefox.nix` - Configuration for Firefox with custom settings and extensions
- `floorp.nix` - Configuration for Floorp Browser
- `msedge.nix` - Configuration for Microsoft Edge
- `opera.nix` - Configuration for Opera Browser

## Usage

The browser configurations are imported by `default.nix` and then included in the main Home Manager configuration. Each browser configuration includes:

- Package installation
- Default browser settings
- Extensions (where applicable)
- Profile configurations

To add a new browser, create a new `.nix` file for that browser and import it in `default.nix`.