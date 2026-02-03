# NixOS Configuration

Multi-host NixOS configuration using flakes, template-based architecture, and Home Manager.

## Hosts

| Host | Type | Hardware | Purpose |
|------|------|----------|---------|
| p620 | workstation | AMD | Primary development |
| p510 | server | Intel Xeon | Media server (Plex) |
| razer | laptop | Intel/NVIDIA | Mobile development |
| samsung | laptop | Intel | Mobile |

## Quick Start

```bash
git clone https://github.com/olafkfreund/nixos_config.git
cd nixos_config
just validate        # Validate configuration
just deploy          # Deploy to current host
just HOST            # Deploy to specific host (p620/p510/razer/samsung)
```

## Directory Structure

```
flake.nix                     Main configuration
justfile                      Automation commands
modules/                      Feature modules
hosts/
  templates/                  Host type templates (workstation/laptop/server)
  p620/, p510/, razer/, samsung/
  common/
home/profiles/                Home Manager profiles
Users/                        Per-user configurations
secrets/                      Agenix encrypted secrets
docs/                         Documentation
```

## Commands

```bash
# Validation
just check-syntax             # Syntax check
just validate                 # Full validation
just test-host HOST           # Test specific host

# Deployment
just deploy                   # Deploy locally
just HOST                     # Deploy to host
just quick-deploy HOST        # Deploy only if changed

# Maintenance
just cleanup                  # Clean old generations
just update-flake             # Update inputs
just secrets                  # Manage secrets

# All commands
just --list
```

## Configuration

Hosts use feature flags:

```nix
features = {
  development.enable = true;
  desktop.enable = true;
  virtualization.enable = true;
};
```

See `hosts/*/configuration.nix` for examples.

## Secrets

```bash
just secrets                              # Interactive manager
./scripts/manage-secrets.sh create NAME   # Create secret
./scripts/manage-secrets.sh edit NAME     # Edit secret
./scripts/manage-secrets.sh rekey         # Rekey all
```

Use runtime loading:

```nix
# Correct
services.myapp.passwordFile = config.age.secrets.password.path;

# Wrong - exposes secret in store
services.myapp.password = builtins.readFile "/secrets/password";
```

## Documentation

- docs/PATTERNS.md - Best practices
- docs/NIXOS-ANTI-PATTERNS.md - Common mistakes
- docs/GITHUB-WORKFLOW.md - Development workflow

## Development

```bash
gh issue develop N --checkout   # Create branch from issue
just test-host HOST             # Test changes
just validate                   # Validate
git commit -m "type: description (#N)"
gh pr create --fill             # Create PR
```

## Troubleshooting

```bash
just check-syntax               # Syntax errors
just diff HOST                  # Show changes
just status                     # System health
nix flake check --show-trace    # Detailed errors
```

## License

See repository for license information.
