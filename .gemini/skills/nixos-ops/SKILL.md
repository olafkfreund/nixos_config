---
name: nixos-ops
version: 1.0
description: "NixOS Operations: Multi-Host Architecture, Deployment & Tooling"
---

# NixOS Operations: Architecture, Deployment & Tooling

> **Operator's Manual for this NixOS Infrastructure**
>
> This skill covers the operational aspects of managing this multi-host NixOS repository: architecture, deployment
> workflows, testing strategies, and tooling integration.

## 🏗️ Project Architecture

### Flake Structure (`flake.nix`)

This repository uses a **unified multi-host flake** architecture.

- **Inputs**: Defined in `flake.nix` (nixpkgs, home-manager, stylix, agenix, etc.).
- **Outputs**: Generates `nixosConfigurations` for all hosts.
- **`makeNixosSystem`**: A helper function in `flake.nix` that standardizes host creation:
  - Injects `specialArgs`: `host`, `username`, `sharedVariables`, `hardwareProfiles`.
  - Sets up **Overlays**: Custom packages and fixes.
  - Configures **Home Manager**: Integrated directly into the NixOS system.

### Host Directory Structure

Hosts are defined in `hosts/<hostname>/`:

```text
hosts/
├── common/              # Shared configurations
│   ├── hardware-profiles/ # GPU/CPU specific configs
│   └── shared-variables.nix
├── p620/                # Host: Primary Workstation
│   ├── configuration.nix # Entry point
│   ├── hardware-configuration.nix
│   └── variables.nix    # Host-specific variables
├── razer/               # Host: Laptop
└── templates/           # Templates for new hosts
```

### Module System

Modules are organized by function in `modules/`:

- **`core/`**: System foundations (boot, locale, nix settings).
- **`desktop/`**: UI environments (GNOME, Hyprland, Cosmic).
- **`services/`**: System services (docker, nginx, tailscale).
- **`features/`**: High-level capability flags (e.g., `features.gaming.enable`).

## 🚀 Deployment Workflows

**Primary Tool: `just`**
This project relies heavily on `Justfile` to abstract complex commands.

### Local Deployment (Current Machine)

```bash
# Standard deploy (uses nh for speed)
just deploy

# Update system (without flake update)
just update
```

### Remote Deployment

Specific targets are defined for each host to handle remote flags (`--target-host`, `--build-host`):

```bash
# Deploy to specific hosts
just p620
just razer
just p510
just samsung  # Special handling for network
```

### Update Workflow

To update `flake.lock` (nixpkgs versions) and deploy:

```bash
# Update inputs and deploy locally
just update-flake

# Interactive workflow (Preview -> Review -> Deploy)
just update-workflow <host>
```

### Emergency Recovery

If tests fail but deployment is critical:

```bash
# Skip all checks and force deploy
just emergency-deploy <host>
```

## 🧪 Testing & Validation

Always validate before deploying to production hosts.

### Pre-Deployment Checks

```bash
# Syntax check only
just check-syntax

# Fast validation (eval only)
just check

# Build config without switching (ensure it compiles)
just test-host <host>
# Example: just test-host razer
```

### Comprehensive Testing

```bash
# Run full suite (features, security, syntax)
just validate

# Test ALL hosts in parallel (heavy load!)
just test-all-parallel
```

## 📦 Package Management

### Custom Packages

Packages are managed via **Overlays** defined in `flake.nix` and `pkgs/`.

- **Add new package**: Create `pkgs/<package-name>/default.nix`.
- **Register**: Add to `overlays` list in `flake.nix`.
- **Test**: `just test-package <package-name>`.

### Finding Packages

```bash
# Search nixpkgs
nix search nixpkgs <query>

# Search installed packages
nix search . <query>
```

## 🛠️ Tooling Reference

### `nh` (Nix Helper)

Used for local operations. Faster than `nixos-rebuild`.

- `nh os switch`: Apply config.
- `nh os test`: Test config.

### `nixos-rebuild`

Used for remote operations.

- `nixos-rebuild switch --flake .#<host> --target-host <host>`

### `agenix` (Secrets)

See `agenix` skill.

- `just secrets`: Interactive secret manager.
- `just test-secrets`: Verify decryption.

## 📝 Best Practices for this Repo

1. **Use `just`**: Avoid running raw `nixos-rebuild` commands; use the recipes.
2. **Test First**: Run `just test-host <target>` before `just <target>`.
3. **Variables**: Use `variables.nix` in host directories for simple toggles instead of hardcoding.
4. **Hardware Profiles**: Import from `hosts/common/hardware-profiles` instead of copy-pasting GPU config.
5. **Clean Up**: Run `just gc` periodically to manage disk space.
