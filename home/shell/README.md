# Shell Configuration

This directory contains configurations for shells and terminal utilities managed through Home Manager.

## Components

- `bash.nix` - Bash shell configuration
- `bat/` - Modern cat replacement configuration
- `default.nix` - Main entry point that imports all shell configurations
- `direnv/` - direnv integration for environment management
- `fzf/` - Fuzzy finder configuration
- `gh/` - GitHub CLI configuration
- `lazyvim/` - LazyVim (Neovim distribution) configuration
- `lf/` - Terminal file manager configuration
- `mail/` - Terminal mail client configuration
- `markdown/` - Markdown processing tools
- `scripts.nix` - Custom shell scripts
- `starship/` - Starship prompt configuration
- `tmux/` - tmux terminal multiplexer configuration
- `yazi/` - Terminal file manager configuration
- `zellij/` - Zellij terminal multiplexer configuration
- `zoxide/` - Smart directory navigation
- `zsh.nix` - Zsh shell configuration with plugins and settings

## Usage

These configurations are imported by the main shell configuration file (`default.nix`) and then included in the user's Home Manager configuration. Each shell component typically includes:

- Package installation
- Configuration files and settings
- Aliases and functions
- Keybindings
- Integration with other tools

The shell configurations provide a consistent terminal experience across different systems with customizations for improved productivity.