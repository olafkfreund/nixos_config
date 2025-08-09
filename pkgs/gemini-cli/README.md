# Gemini CLI NixOS Package

This package provides the Google Gemini CLI tool for NixOS systems.

## About

The Gemini CLI is a command-line AI workflow tool that connects to your tools, understands your code, and accelerates your workflows. It provides an interactive interface to Google's Gemini AI models.

## Installation

### From this flake

```bash
# Run directly
nix run .#gemini-cli

# Install to profile
nix profile install .#gemini-cli

# Add to your NixOS configuration
# In your configuration.nix or flake, add:
environment.systemPackages = [ inputs.your-flake.packages.x86_64-linux.gemini-cli ];
```

### Build locally

```bash
cd pkgs/gemini-cli
nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix {}'
```

## Usage

```bash
# Get version
gemini --version

# Get help
gemini --help

# Start interactive session
gemini

# Use with a specific model
gemini -m gemini-2.5-pro

# Run in sandbox mode
gemini -s

# Debug mode
gemini -d
```

## Features

- Interactive AI workflow tool
- Support for multiple Gemini models
- Sandbox execution capabilities
- File context understanding
- Code analysis and generation
- Checkpointing support
- Telemetry options

## Configuration

The CLI supports various authentication methods:

- API key via `GEMINI_API_KEY` environment variable
- Google account OAuth
- Google Workspace accounts

For detailed configuration options, see the [official documentation](https://github.com/google-gemini/gemini-cli).

## Package Details

- **Version**: 0.1.3-unstable-2025-06-25
- **Source**: Built from GitHub repository at commit `b6b9923d`
- **License**: Apache 2.0
- **Node.js requirement**: 18+

## Development

To update the package:

1. Update the `rev` field in `default.nix` to the latest commit
2. Update the `hash` field (run build once to get the new hash)
3. If dependencies change, update `npmDepsHash` (run build once to get the new hash)
4. Test the build: `nix build .#gemini-cli`
