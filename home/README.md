# Home Configuration

This directory contains Home Manager configurations for user environments. Home Manager is used to manage user-specific configurations and packages.

## Directory Structure

- `browsers/` - Browser configurations (Brave, Chrome, Firefox, Floorp, Opera, etc.)
- `chat/` - Messaging applications including Discord (Nixcord)
- `desktop/` - Desktop environment configurations
  - Window managers (Hyprland, Sway)
  - Desktop utilities (dunst, waybar, rofi, etc.)
  - Terminal emulators
  - Theme configurations
- `development/` - Development tools and configurations
  - Editor configurations (VSCode, Neovim, Emacs, Zed)
  - Development containers (distrobox)
- `files/` - Configuration files and assets
- `games/` - Gaming-related configurations (Steam)
- `media/` - Media playback configurations (music, MPD)
- `network/` - Network-related configurations
- `shell/` - Shell configurations
  - ZSH and Bash configurations
  - Terminal utilities (bat, fzf, direnv, etc.)
  - Terminal multiplexers (tmux, zellij)

## Usage

These configurations are imported by the user configuration files in the `Users/` directory. The main entry point is `default.nix` which imports all the necessary modules.

For desktop and server configurations, separate entry points exist:
- `desktop.nix` - For regular desktop systems
- `servers.nix` - For server systems with minimal desktop components