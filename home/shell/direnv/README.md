# Direnv Configuration

This directory contains the configuration for [direnv](https://direnv.net/), a tool that loads and unloads environment variables depending on the current directory.

## Overview

Direnv is integrated with your NixOS configuration to enable:
- Automatic loading of project-specific environment variables
- Seamless integration with Nix development environments
- Per-directory environment management

## Features

- Integration with both bash and zsh shells
- Support for Nix development environments (via nix-direnv)
- Automatic activation/deactivation when entering/leaving directories with `.envrc` files

## Usage

When you navigate into a directory containing an `.envrc` file, direnv automatically:
1. Loads the environment specified in the file
2. Shows a notification about the environment change
3. Makes all specified environment variables available to your shell

Common use cases:
- Project-specific environment variables
- Language-specific configuration
- Automatic activation of virtual environments

```bash
# Example .envrc file
export PROJECT_ROOT=$(pwd)
export DATABASE_URL="postgres://localhost:5432/mydb"
layout python  # Activate Python virtualenv
```

Direnv is activated in both your bash and zsh configurations:
```bash
eval "$(direnv hook bash)"
```