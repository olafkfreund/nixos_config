# NixOS Modules

This directory contains modular NixOS configurations that can be imported by different host configurations. These modules provide reusable functionality across systems.

## Module Categories

- `ai/` - AI-related tools and configurations (ollama, chatgpt)
- `cloud/` - Cloud provider tooling (AWS, Azure, Google Cloud)
- `containers/` - Container runtime configurations
- `desktop/` - Desktop environment modules
- `development/` - Development tool modules
- `fonts/` - Font configurations
- `hardware/` - Hardware-specific modules
- `helpers/` - Helper functions and utilities
- `intune-portal/` - Microsoft Intune portal configurations
- `laptop-related/` - Laptop-specific configurations
- `nix/` - Nix package manager configurations
- `nix-index/` - Nix index database configuration
- `obsidian/` - Obsidian note-taking app configuration
- `office/` - Office applications
- `overlays/` - Nixpkgs overlays
- `pkgs/` - Custom package definitions
- `playmouth/` - Boot splash screen configurations
- `programs/` - Various program configurations
- `security/` - Security-related configurations
- `services/` - System service configurations
- `spell/` - Spell checking tools
- `ssh/` - SSH configurations
- `system-scripts/` - System maintenance scripts
- `system-tweaks/` - Performance and behavior tweaks
- `system-utils/` - System utilities
- `virt/` - Virtualization tools (libvirt, incus, podman)
- `webcam/` - Webcam utilities

## Usage

These modules are imported by host configurations in the `hosts/` directory. The main entry point is `default.nix` which imports common modules needed by most systems.

For specialized system types, separate entry points exist:

- `server.nix` - For server systems
- `laptops.nix` - For laptop systems
