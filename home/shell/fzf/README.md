# FZF Configuration

This directory contains configuration for [fzf](https://github.com/junegunn/fzf), a command-line fuzzy finder.

## Overview

FZF is configured in this NixOS setup to enhance your command-line experience with:
- Fuzzy search capabilities for files, command history, and processes
- Integration with shell keybindings for quick access
- Customized appearance with gruvbox theme integration

## Features

- Shell integrations for both bash and zsh
- Custom key bindings for improved workflow
- Integration with other tools like bat, eza, and ripgrep
- Preview capabilities for files

## Usage

FZF provides several key bindings:
- `Ctrl+T`: Paste selected files/folders onto the command line
- `Ctrl+R`: Search command history with fuzzy matching
- `Alt+C`: Fuzzy change directory
- `**<Tab>`: Fuzzy path completion

In your configuration, fzf is used in several custom aliases and integrations:
- Integration with zsh fzf-tab for enhanced tab completion
- Custom preview commands using eza and bat
- Custom appearance settings matching your gruvbox theme

```bash
# Example integration showing file search with preview
f = "$vi $(fzf)"

# fzf-tab integration with customized preview
zstyle ':fzf-tab:complete:*:*' fzf-preview 'eza --icons -a --group-directories-first -1 --color=always $realpath'
```