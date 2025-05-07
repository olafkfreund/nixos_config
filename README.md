# NixOS Configuration

My personal NixOS configuration with Home Manager integration and multi-host support.

## System Overview

This flake-based NixOS configuration provides:

- Multiple host configurations (razer, lms, dex5550, hp, p510, p620)
- Home Manager integration for user environment management
- Theme management with Stylix (Gruvbox theme)
- Development environment setup (VS Code, Neovim, terminal tools)
- Desktop environments and window managers
- Various application configurations

## Getting Started

### Prerequisites

- NixOS with flakes enabled
- Git

### Installation

1. Install git if not already available:

```shell
nix-env -iA nixos.git
```

2. Clone the repository:

```shell
git clone git@github.com:olafkfreund/nixos_config.git
```

3. Enter the cloned directory:

```shell
cd nixos_config
```

4. Copy the contents to your NixOS configuration directory:

```shell
sudo rsync -av --exclude='.git' ./* ~/.config/nixos
```

5. Set appropriate permissions:

```shell
sudo chown -R $(whoami):$(id -gn) ~/.config/nixos
```

## Using This Flake

### Rebuilding Your System

To rebuild your system using this flake, run:

```shell
sudo nixos-rebuild switch --flake ~/.config/nixos#hostname
```

Replace `hostname` with one of the available configurations: razer, lms, dex5550, hp, p510, or p620.

### Updating the Flake

To update all flake inputs:

```shell
nix flake update ~/.config/nixos
```

To update a specific input:

```shell
nix flake lock --update-input nixpkgs ~/.config/nixos
```

## Configuration Structure

- `flake.nix` - The main flake configuration with all inputs and outputs
- `hosts/` - Host-specific configurations
- `home/` - Home Manager configurations for user environment
  - `browsers/` - Browser configurations (Brave, Chrome, Firefox, etc.)
  - `chat/` - Messaging applications
  - `desktop/` - Desktop environment settings
  - `development/` - Development tools configuration
  - `shell/` - Shell configurations (Bash, ZSH)
- `modules/` - Modular system configurations
- `themes/` - Theme configurations
- `pkgs/` - Custom package definitions

## Key Features

- VS Code setup with Context7 MCP server integration
- Neovim configuration
- Multiple terminal emulator options
- Browser configurations
- Desktop environments (KDE Plasma, Hyprland, Sway)
- Development tooling (containers, shells, editors)
- Media applications
- Gaming setup

## Customization

To customize for your own use:

1. Modify the username in `flake.nix`
2. Create or modify host configurations in the `hosts/` directory
3. Adjust Home Manager configurations in `home/` and `Users/`

## License

See the LICENSE file for details.
