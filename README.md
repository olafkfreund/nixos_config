# NixOS Modular Configuration

This repository contains a modular, flake-based NixOS configuration with Home Manager integration and multi-host support. It is designed for reproducibility, maintainability, and easy onboarding for new users or contributors.

## System Overview

- **Multi-host support:** Each host has its own directory under `hosts/` with hardware-specific and system settings. Host-specific variables are managed in `variables.nix` files for consistency and easy updates.
- **Modular structure:** System configuration is split into reusable modules under `modules/` (e.g., cloud, containers, desktop, development, security, services, virtualization, etc.).
- **Home Manager integration:** User environments are managed declaratively in `home/` and imported per-host.
- **Custom packages:** The `pkgs/` directory contains custom Nix packages and overlays not available in upstream nixpkgs.
- **Theme and appearance:** Gruvbox-based themes and wallpapers are provided in `themes/` and integrated system-wide.

## Onboarding & Usage

1. **Clone the repository:**

   ```sh
   git clone <this-repo-url> ~/.config/nixos
   cd ~/.config/nixos
   ```

2. **Select or create your host directory:**
   - Each host (machine) has a directory under `hosts/` (e.g., `hosts/p620/`, `hosts/razer/`).
   - Copy an existing host as a template or create a new one. Set hardware-specific options in `variables.nix`.
3. **Edit your configuration:**
   - System-level modules are imported in `configuration.nix`.
   - User-level (Home Manager) configs are in `home/` and imported per-host.
   - Enable/disable features using the `features` attribute in your host config.
4. **Build and switch:**

   ```sh
   sudo nixos-rebuild switch --flake .#<hostname>
   # For home-manager only:
   home-manager switch --flake .#<username>@<hostname>
   ```

5. **Update system:**
   - Use the provided scripts in `scripts/` (e.g., `check-nixos-updates.sh`) to check for flake updates.
   - Pull latest changes and run rebuild as above.

## Key Concepts

- **variables.nix:** Each host has a `variables.nix` file for user, display, GPU, and other hardware-specific settings. This enables easy reuse and consistency.
- **Feature flags:** The `features` attribute in host configs enables or disables groups of functionality (development tools, cloud, virtualization, etc.).
- **Modular imports:** System and user configs are composed from many small, focused modules for maintainability.
- **Custom overlays:** The `pkgs/` directory can override or extend upstream Nix packages.
- **Declarative user environments:** Home Manager is used for all user-level configuration, including shells, editors, and desktop environments.

## Directory Structure

- `hosts/` — Per-host system configuration (hardware, variables, options)
- `modules/` — Reusable NixOS modules (cloud, containers, desktop, etc.)
- `home/` — Home Manager user environment modules
- `pkgs/` — Custom Nix packages and overlays
- `themes/` — Theme files and wallpapers
- `scripts/` — Utility scripts for system management
- `Users/` — User-specific Home Manager configs

## Contributing

- Follow the modular structure and use feature flags for new functionality.
- Add new hosts by copying an existing host directory and updating `variables.nix`.
- Document new modules and features in their respective `README.md` files.
- See `.github/copilot-instructions.md` in each host for coding standards.

## References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nixpkgs Contribution Guide](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md)
