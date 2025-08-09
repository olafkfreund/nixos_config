# Home Manager & NixOS Modular Configuration

This directory contains Home Manager configurations for user environments and is part of a modular, flake-based NixOS configuration system. The setup is designed for reproducibility, maintainability, and easy onboarding for new users or contributors.

## Onboarding & Usage

### How to Use This Configuration

1. **Clone the repository** to your NixOS system:

   ```sh
   git clone <your-repo-url> ~/.config/nixos
   cd ~/.config/nixos
   ```

2. **Review the directory structure:**
   - `hosts/` — Host-specific system configurations (hardware, networking, etc.)
   - `modules/` — Reusable NixOS modules (desktop, development, cloud, security, etc.)
   - `home/` — Home Manager user environment configs (shell, desktop, development, etc.)
   - `pkgs/` — Custom package definitions
   - `themes/` — Theme files (Gruvbox, etc.)
   - `scripts/` — Utility scripts for system management

3. **Select or create your host configuration:**
   - Copy an existing host directory in `hosts/` or create a new one using the templates in `modules/common/templates/`.
   - Edit `variables.nix` in your host directory to set user, display, and hardware-specific settings.

4. **Enable or disable features:**
   - Use the `features` attribute in your host's `configuration.nix` to enable development tools, virtualization, cloud tools, security, and more.
   - Home Manager options can be overridden per host in `home-manager-options.nix`.

5. **Apply the configuration:**
   - For system config:

     ```sh
     sudo nixos-rebuild switch --flake .#<hostname>
     ```

   - For user config (Home Manager):

     ```sh
     home-manager switch --flake .#<username>@<hostname>
     ```

## Key Concepts

- **Modular Design:**
  - System and user environments are split into reusable modules for easy maintenance and extension.
  - Host-specific variables are centralized in `variables.nix` for each host.

- **Feature Flags:**
  - Enable/disable features (development, virtualization, cloud, security, etc.) per host using the `features` attribute.

- **Home Manager Integration:**
  - User environments (shell, desktop, development tools) are managed declaratively and can be customized per host.

- **Custom Packages & Themes:**
  - Custom Nix packages and themes are defined in `pkgs/` and `themes/`.

- **Onboarding:**
  - New users can quickly onboard by copying a host template, setting variables, and enabling desired features.

## Directory Overview

- `hosts/` — System configs for each machine
- `modules/` — Modular NixOS and Home Manager modules
- `home/` — User environment configs (shell, desktop, development, etc.)
- `pkgs/` — Custom Nix packages
- `themes/` — Theme files (Gruvbox, etc.)
- `scripts/` — Utility scripts

## Best Practices

- Keep host-specific settings in `variables.nix` for clarity and reusability.
- Use feature flags to enable only what you need per host.
- Read the `README.md` files in each subdirectory for detailed documentation and usage examples.
- Use the modular approach to easily add, remove, or update features across all systems.

---

For more details, see the `README.md` files in each subdirectory and the comments in the Nix files themselves.
