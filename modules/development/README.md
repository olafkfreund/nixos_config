# Development Modules

This directory contains NixOS modules for various development environments and tools.

## Available Modules

- `default.nix` - Main entry point that imports all development modules
- `cargo.nix` - Rust development tools and Cargo package manager
- `cue.nix` - CUE language support
- `devshell.nix` - Development shell environments
- `github.nix` - GitHub CLI and related tools
- `go.nix` - Go language development environment
- `java.nix` - Java development environment
- `lua.nix` - Lua programming language tools
- `nix.nix` - Nix language development tools
- `nodejs.nix` - Node.js development environment
- `python.nix` - Python development environment and tools
- `shell.nix` - Shell development utilities

## Usage

These modules can be enabled selectively in host configurations to provide development tools for specific languages or environments. Each module typically defines:

- Required packages
- Language servers
- Build tools
- Development utilities
- IDE support tools

Enable these modules in your host's configuration.nix file:

```nix
{
  python.development.enable = true;
  nodejs.development.enable = true;
  # ... other development modules
}
```
