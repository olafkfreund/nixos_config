# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a sophisticated multi-host NixOS configuration using flakes with extensive modularization, secrets management, and automation. The repository manages 4 active hosts with different hardware profiles and supports multi-user environments.

## Key Commands

### Building and Testing
```bash
# Validate entire configuration
just validate

# Test specific host
just test-host p620

# Test all hosts
just test-all

# Run full CI pipeline
just ci

# Quick validation
just validate-quick

# Check Nix syntax
just check-syntax

# Test module structure
just test-modules

# Format all Nix files
just format

# Performance testing
just perf-test
```

### Deployment
```bash
# Deploy to local system
just deploy

# Deploy to specific hosts
just p620    # AMD workstation with ROCm
just razer   # Intel/NVIDIA laptop
just p510    # Intel Xeon/NVIDIA workstation
just dex5550 # Intel SFF with integrated graphics

# Update system
just update

# Update flake inputs
just update-flake
```

### Secrets Management
```bash
# Interactive secrets management
./scripts/manage-secrets.sh

# Create new secret
./scripts/manage-secrets.sh create SECRET_NAME

# Edit existing secret
./scripts/manage-secrets.sh edit SECRET_NAME

# Rekey all secrets
./scripts/manage-secrets.sh rekey

# Check secrets status
./scripts/manage-secrets.sh status
```

## Architecture

### Directory Structure
- `flake.nix` - Main entry point defining hosts and configurations
- `hosts/` - Host-specific configurations (p620, razer, p510, dex5550)
- `modules/` - Reusable NixOS modules organized by category
- `home/` - Home Manager base configurations
- `Users/` - Per-user configurations with host-specific home files
- `secrets/` - Encrypted secrets using Agenix
- `scripts/` - Management and utility scripts

### Host Configuration Pattern
Each host has:
- `configuration.nix` - Main NixOS configuration
- `variables.nix` - Host-specific variables (users, features, hardware)
- `hardware-configuration.nix` - Generated hardware configuration

### Module System
Modules use a consistent pattern with feature flags:
```nix
features = {
  development = {
    enable = true;
    python = true;
    go = true;
  };
  virtualization = {
    enable = true;
    docker = true;
  };
}
```

### Multi-User Support
Users are defined per-host in `variables.nix`:
```nix
hostUsers = [ "olafkfreund" "anotheruser" ];
```

Each user has configurations in `Users/username/` with host-specific home files like `p620_home.nix`.

### Secrets Management
- Uses Agenix for encrypted secrets
- Secrets named as `user-password-USERNAME.age`
- Access controlled via SSH keys in `secrets.nix`
- Host and user-specific access control

## Important Conventions

1. **Always verify packages exist** before using them in configurations
2. **Use feature flags** for conditional module loading
3. **Test changes** with `just test-host HOST` before deploying
4. **Format code** with `just format` before committing
5. **Validate** with `just validate` for comprehensive checks
6. **Secrets** must be created through the management script, never hardcoded

## Hardware-Specific Considerations

- **P620**: AMD GPU requires ROCm support, uses `amdgpu` driver
- **Razer**: Hybrid Intel/NVIDIA graphics needs Optimus configuration
- **P510**: Intel Xeon with NVIDIA requires CUDA support
- **DEX5550**: Intel integrated graphics, optimized for efficiency

## Testing Workflow

1. Make changes to configuration
2. Run `just check-syntax` to verify syntax
3. Run `just test-host HOST` to test build
4. Run `just validate` for comprehensive validation
5. Deploy with `just HOST` or `just deploy` for local

## Common Development Tasks

### Adding a new module
1. Create module file in appropriate `modules/` subdirectory
2. Follow existing module patterns with enable options
3. Add to module imports in `modules/default.nix`
4. Test with `just test-modules`

### Adding a new user
1. Add username to host's `variables.nix` hostUsers
2. Create user directory `Users/newuser/`
3. Create host-specific home files
4. Add SSH key to `secrets.nix`
5. Create password secret with `./scripts/manage-secrets.sh create user-password-newuser`
6. Deploy configuration

### Updating dependencies
```bash
just update-flake  # Update all flake inputs
just update-input INPUT_NAME  # Update specific input
```

## Network and Cache Configuration

- Binary cache server on P620: `http://p620:5000`
- Tailscale VPN integration for remote access
- Network stability module for connection monitoring