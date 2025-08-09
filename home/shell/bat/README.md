# Bat Configuration

This directory contains configuration for [bat](https://github.com/sharkdp/bat), a cat clone with syntax highlighting and Git integration.

## Overview

Bat is configured in this NixOS setup to provide:

- Syntax highlighting with the gruvbox-dark theme (as referenced in your shell aliases)
- Integration with git for showing file changes
- A more readable alternative to the standard `cat` command

## Configuration

The configuration in this directory integrates bat into your shell environment with the following features:

- Custom theme settings
- Integration with other tools like fzf for previews
- File type association for syntax highlighting

## Usage

In your system, bat is aliased to use the gruvbox-dark theme:

```bash
# In your shell configuration
cat = "bat --theme=gruvbox-dark";
```

You can use bat directly with:

```bash
bat <filename>
```

Or through the alias:

```bash
cat <filename>
```
