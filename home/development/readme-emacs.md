# NixOS Emacs Configuration

This document provides a comprehensive guide to the Emacs configuration used in this NixOS setup. The configuration is built with NixOS's declarative approach, using Home Manager to manage Emacs and its packages.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Core Configuration](#core-configuration)
- [UI and Theming](#ui-and-theming)
- [Keybindings](#keybindings)
  - [Global Keybindings](#global-keybindings)
  - [Nix Development](#nix-development)
  - [File Navigation](#file-navigation)
  - [Project Management](#project-management)
  - [Code Development](#code-development)
  - [Version Control](#version-control)
  - [Treemacs](#treemacs)
  - [LSP](#lsp)
  - [Language-Specific](#language-specific)
  - [Org Mode](#org-mode)
  - [Email](#email)
  - [SOPS Encryption](#sops-encryption)
  - [Copilot](#copilot)
- [Features](#features)
  - [Nix Integration](#nix-integration)
  - [Language Support](#language-support)
  - [Development Tools](#development-tools)
  - [Email and Communication](#email-and-communication)
  - [Note-Taking and Organization](#note-taking-and-organization)
- [Package List](#package-list)
- [Customization](#customization)

## Overview

This Emacs configuration is designed for NixOS users, with a focus on a modern development environment. It features:

- Clean, minimal UI with Gruvbox theme
- Comprehensive language support with LSP integration
- NixOS-specific tooling (nix-sandbox, nixos-options)
- Project management via Projectile
- Git integration with Magit
- AI assistance with GitHub Copilot
- Enhanced productivity with fzf, treemacs, and company
- Org-mode and org-roam for note-taking
- Email support via mu4e
- RSS feed reading with elfeed

## Installation

The configuration is managed through NixOS and Home Manager. To use this setup:

1. Ensure your flake.nix imports the home-manager modules
2. Make sure the Emacs configuration module is properly referenced in your home configuration
3. Run `nixos-rebuild switch` to apply the changes

The configuration is located at: `/home/olafkfreund/.config/nixos/home/development/emacs.nix`

## Core Configuration

The Emacs configuration consists of several key files:

- `early-init.el`: Loaded before initialization
- `init.el`: Main initialization file
- `config.el`: Core configuration settings
- `custom-vars.el`: Custom variables managed by Emacs

The `emacs.nix` file in the NixOS configuration manages these files and declares all the required Emacs packages.

## UI and Theming

- **Theme**: Gruvbox Dark Medium
- **Modeline**: Doom modeline
- **Font**: System font at height 110
- **Icons**: all-the-icons
- **Dashboard**: Custom startup screen with NixOS banner
- **Clean UI**: No menu bar, toolbar, or scrollbar

## Keybindings

### Global Keybindings

| Keybinding | Description |
|------------|-------------|
| `C-h b` | Show all top-level keybindings |
| `C-h m` | Show major mode keybindings |
| `C-x g` | Open Magit status |

### Nix Development

| Keybinding | Description |
|------------|-------------|
| `C-c n s` | Open nix-sandbox shell |
| `C-c n b` | Compile within nix-sandbox |
| `C-c n r` | Run command in nix-sandbox |
| `C-c C-o` | Show NixOS options documentation (in nix-mode) |
| `C-c C-d` | Show NixOS options for item at point (in nix-mode) |
| `C-c C-l` | Enable LSP in nix-mode (for large files) |

### File Navigation

| Keybinding | Description |
|------------|-------------|
| `C-c f f` | Find files using fzf |
| `C-c f d` | Find files in specific directory |
| `C-c f g` | Grep in current directory with fzf |
| `C-c f p` | Find git-tracked files with fzf |
| `C-c f b` | Switch buffer using fzf |
| `M-p` | Find files in current project with fzf |

### Project Management

| Keybinding | Description |
|------------|-------------|
| `C-c p` | Projectile command prefix |
| `C-c p f` | Find file in project |
| `C-c p p` | Switch projects |
| `C-c p b` | Switch to project buffer |
| `C-c p s s` | Search in project |
| `C-c p c` | Compile project (`nixos-rebuild build` for NixOS config) |
| `C-c p t` | Run project tests (`nixos-rebuild test` for NixOS config) |
| `C-c p r` | Run project (`nixos-rebuild switch` for NixOS config) |

### Code Development

| Keybinding | Description |
|------------|-------------|
| `C-TAB` / `C-<tab>` | Accept GitHub Copilot suggestion |
| `C-c C-c` | Toggle Copilot Chat mode |
| `TAB` | Company completion |
| `M-n` / `M-p` | Navigate completion candidates |

### Version Control

| Keybinding | Description |
|------------|-------------|
| `C-x g` | Open Magit status |
| `C-x M-g` | Open Magit dispatch menu |
| `C-c M-g` | Open Magit file dispatch |

### Treemacs

| Keybinding | Description |
|------------|-------------|
| `C-c t t` | Toggle Treemacs |
| `C-c t b` | Add bookmark |
| `C-c t f` | Find file in workspace |
| `C-c t p` | Find file in current project |

### LSP

| Keybinding | Description |
|------------|-------------|
| `C-c l` | LSP command prefix |
| `C-c l g r` | Find references |
| `C-c l g d` | Go to definition |
| `C-c l r r` | Rename symbol |
| `C-c l a` | Execute code action |
| `C-c l f` | Format buffer/region |

### Language-Specific

#### Python

| Keybinding | Description |
|------------|-------------|
| `C-c C-t` | Run tests in Python file |

#### Go

| Keybinding | Description |
|------------|-------------|
| `C-c C-t` | Run tests in Go file |

### Org Mode

Org mode uses its own extensive set of keybindings. Some notable ones:

| Keybinding | Description |
|------------|-------------|
| `C-c l` | Org store link |
| `C-c a` | Org agenda |
| `C-c c` | Org capture |
| `TAB` | Toggle visibility |
| `M-<left>/<right>` | Promote/demote heading or item |

### Email

| Keybinding | Description |
|------------|-------------|
| `C-x m` | Compose new mail (when mu4e is active) |
| `j` | In mu4e, jump to folder |
| `u` | In mu4e, update mail and index |

### SOPS Encryption

| Keybinding | Description |
|------------|-------------|
| `C-c C-s e` | Encrypt buffer with SOPS |
| `C-c C-s d` | Decrypt buffer with SOPS |
| `C-c C-s c` | Show SOPS comment |

### Copilot

| Keybinding | Description |
|------------|-------------|
| `C-TAB` / `C-<tab>` | Accept Copilot suggestion |
| `C-c C-c` | Toggle Copilot Chat mode |

## Features

### Nix Integration

- **nix-sandbox**: Isolated Nix environments for compiling and running code
- **nixos-options**: Browse NixOS options with documentation
- **nix-mode**: Syntax highlighting and indentation for Nix files
- **nixpkgs-fmt**: Optional code formatting for Nix files
- **direnv**: Automatic loading of environment from .envrc files
- **envrc**: Integration with direnv for project-specific environments

### Language Support

This configuration provides enhanced support for:

- **Python**: LSP, Black formatting, isort, pytest integration
- **Go**: LSP, eldoc, testing tools, struct tag management
- **Nix**: Syntax highlighting, LSP with nixd, performance optimizations
- **Terraform**: LSP, formatting, autocompletion
- **Web Development**: HTML, CSS, JavaScript, TypeScript
- **Rust**: LSP integration
- **Markdown**: Preview, TOC generation, GitHub flavored markdown

### Development Tools

- **LSP**: Language Server Protocol for code intelligence
- **Treemacs**: File explorer with project integration
- **Company**: Autocompletion framework
- **Flycheck**: Real-time syntax checking
- **Magit**: Git interface
- **Projectile**: Project interaction library
- **Yasnippet**: Template system
- **Which-key**: Keybinding help
- **Copilot**: AI code completion
- **Copilot Chat**: AI code assistant

### Email and Communication

- **mu4e**: Email client integrated with Emacs
- **elfeed**: RSS reader for staying updated

### Note-Taking and Organization

- **Org Mode**: Outlining, task management, literate programming
- **Org-roam**: Networked note-taking based on the Zettelkasten method
- **Org-bullets**: Better bullet rendering in org-mode
- **Org-present**: Minimalist presentation tool

## Package List

The configuration includes a comprehensive set of packages:

- **UI**: gruvbox-theme, doom-modeline, all-the-icons, dashboard
- **Navigation**: projectile, treemacs, fzf
- **Development**: lsp-mode, company, flycheck, magit
- **Languages**: nix-mode, terraform-mode, python-mode, go-mode, web-mode
- **AI**: copilot, gptel, copilot-chat
- **Encryption**: sops, age
- **Email/RSS**: mu4e, mu4e-views, elfeed, elfeed-org
- **Org**: org, org-roam, org-bullets
- **Utilities**: which-key, helpful, yasnippet

## Customization

To customize this configuration:

1. Modify the `emacs.nix` file to add or remove packages
2. Add custom configurations to `config.el`
3. Run `nixos-rebuild switch` to apply changes

For non-NixOS specific configurations, you can add them to `~/.emacs.d/custom-vars.el`.

---

For more details about specific packages, refer to their documentation:
- [Nix Mode](https://github.com/NixOS/nix-mode)
- [Projectile](https://docs.projectile.mx/projectile/index.html)
- [LSP Mode](https://emacs-lsp.github.io/lsp-mode/)
- [Org Mode](https://orgmode.org/manual/)
- [Magit](https://magit.vc/manual/)