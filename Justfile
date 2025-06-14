# NixOS Configuration Management Justfile
# Updated for unified flake architecture with comprehensive tooling

# Default recipe to list available commands
default:
    @just --list

# === BUILD & DEPLOYMENT ===

# Quick switch for current host
deploy:
    nh os switch

# Deploy to specific local host
deploy-host HOST:
    sudo nixos-rebuild switch --flake .#{{HOST}}

# Build without switching (test build)
build HOST:
    nixos-rebuild build --flake .#{{HOST}}

# Build and test configuration without switching to it
test HOST:
    sudo nixos-rebuild test --flake .#{{HOST}}

# Deploy to remote host
deploy-remote HOST:
    nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}} --build-host {{HOST}} --use-remote-sudo --impure --accept-flake-config

# === VALIDATION & TESTING ===

# Validate flake configuration
check:
    nix flake check

# Run comprehensive configuration validation
validate:
    ./scripts/validate-config.sh

# Validate specific component
validate-component COMPONENT:
    ./scripts/validate-config.sh {{COMPONENT}}

# Check syntax only
validate-syntax:
    ./scripts/validate-config.sh syntax

# Validate profiles
validate-profiles:
    ./scripts/validate-config.sh profiles

# Validate hardware modules
validate-hardware:
    ./scripts/validate-config.sh hardware

# === HOST-SPECIFIC DEPLOYMENTS ===

# AMD Workstation (P620)
p620:
    nixos-rebuild switch --flake .#p620 --target-host p620 --build-host p620 --use-remote-sudo --impure --accept-flake-config

# Intel Laptop (Razer)
razer:
    nixos-rebuild switch --flake .#razer --target-host razer --build-host razer --use-remote-sudo --impure --accept-flake-config

# NVIDIA Gaming (P510)
p510:
    nixos-rebuild switch --flake .#p510 --target-host p510 --build-host p510 --use-remote-sudo --impure --accept-flake-config

# Intel HTPC (DEX5550)
dex5550:
    nixos-rebuild switch --flake .#dex5550 --target-host dex5550 --build-host dex5550 --use-remote-sudo --impure --accept-flake-config

# HP Host
hp:
    nixos-rebuild switch --flake .#hp --target-host hp --build-host hp --use-remote-sudo --impure --accept-flake-config 

# LMS Host
lms:
    nixos-rebuild switch --flake .#lms --target-host lms --build-host lms --use-remote-sudo --impure --accept-flake-config

# PVM Host
pvm:
    nixos-rebuild switch --flake .#pvm --target-host pvm --build-host pvm --use-remote-sudo --impure --accept-flake-config

# === SYSTEM MAINTENANCE ===

# Update system and flake inputs
update:
    nh os update

# Update specific input
update-input INPUT:
    nix flake update {{INPUT}}

# Show system generation history
history:
    nix profile history --profile /nix/var/nix/profiles/system

# Garbage collection
gc:
    sudo nix-collect-garbage --delete-old

# Aggressive garbage collection (delete all old generations)
gc-aggressive:
    sudo nix-collect-garbage -d

# Optimize nix store
optimize:
    sudo nix-store --optimize

# === SECRETS MANAGEMENT ===

# Initialize secrets management
secrets-init:
    ./scripts/manage-secrets.sh init

# Create new secret
secrets-create SECRET:
    ./scripts/manage-secrets.sh create {{SECRET}}

# Edit existing secret
secrets-edit SECRET:
    ./scripts/manage-secrets.sh edit {{SECRET}}

# List all secrets
secrets-list:
    ./scripts/manage-secrets.sh list

# Check secrets status
secrets-status:
    ./scripts/manage-secrets.sh status

# Rekey all secrets
secrets-rekey:
    ./scripts/manage-secrets.sh rekey

# Recover secrets
secrets-recover:
    ./scripts/recover-secrets.sh

# Setup secrets for new host
secrets-setup:
    ./scripts/setup-secrets.sh

# === HOME MANAGER ===

# Switch Home Manager configuration
home-switch USER HOST:
    home-manager switch --flake .#{{USER}}@{{HOST}}

# Build Home Manager configuration
home-build USER HOST:
    home-manager build --flake .#{{USER}}@{{HOST}}

# === DEVELOPMENT & DEBUGGING ===

# Enter development shell
dev:
    nix develop

# Open Nix REPL with nixpkgs
repl:
    nix repl -f flake:nixpkgs

# Format all Nix files
format:
    alejandra .

# Lint Nix files
lint:
    statix check .

# Find dead code
deadnix:
    deadnix .

# Run all code quality checks
quality: format lint deadnix

# === MONITORING & DIAGNOSTICS ===

# Check for NixOS updates
check-updates:
    ./scripts/check-nixos-updates.sh

# Monitor network stability
network-monitor:
    ./scripts/network-monitor.sh

# Network stability helper
network-stability:
    ./scripts/network-stability-helper.sh

# Toggle VFIO configuration
toggle-vfio:
    ./scripts/toggle-vfio.sh

# === MIGRATION & BACKUP ===

# Run configuration migration
migrate:
    ./scripts/migrate-config.sh

# Dry run migration
migrate-dry:
    ./scripts/migrate-config.sh --dry-run

# Create backup
backup:
    ./scripts/migrate-config.sh backup

# === TEMPLATES & DOCUMENTATION ===

# List available templates
templates:
    ls -la templates/

# Copy minimal template for new host
template-minimal HOST:
    cp -r templates/minimal hosts/{{HOST}}

# Copy workstation template for new host
template-workstation HOST:
    cp -r templates/workstation hosts/{{HOST}}

# Generate hardware configuration for new host
hardware-config HOST:
    sudo nixos-generate-config --show-hardware-config > hosts/{{HOST}}/nixos/hardware-configuration.nix

# === PACKAGE MANAGEMENT ===

# Search for packages
search PACKAGE:
    nix search nixpkgs {{PACKAGE}}

# Show package information
info PACKAGE:
    nix show-derivation nixpkgs#{{PACKAGE}}

# Build custom package
build-pkg PACKAGE:
    nix build .#{{PACKAGE}}

# === QUICK DIAGNOSTICS ===

# Show system info
sysinfo:
    neofetch || (echo "neofetch not installed, showing basic info:" && uname -a && uptime)

# Show generation sizes
gen-sizes:
    nix profile history --profile /nix/var/nix/profiles/system | head -10

# Check disk usage
disk-usage:
    df -h / /nix

# Show failed services
failed-services:
    systemctl --failed

# === EMERGENCY & RECOVERY ===

# Rollback to previous generation
rollback:
    sudo nixos-rebuild switch --rollback

# Boot into previous generation
rollback-boot:
    sudo nixos-rebuild boot --rollback

# Emergency rollback (for broken systems)
emergency-rollback GEN:
    sudo nix-env --switch-generation {{GEN}} --profile /nix/var/nix/profiles/system && sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch

# === SAFE TESTING & PREVIEW ===

# Dry run - show what would change without applying
dry-run HOST:
    nixos-rebuild dry-run --flake .#{{HOST}}

# Build and activate temporarily (reverts on reboot)
test-run HOST:
    sudo nixos-rebuild test --flake .#{{HOST}}

# Show differences between current and new configuration
diff HOST:
    nixos-rebuild build --flake .#{{HOST}} && \
    nix store diff-closures /run/current-system ./result

# Compare configurations without building
diff-config HOST:
    nix eval --raw .#nixosConfigurations.{{HOST}}.config.system.build.toplevel.drvPath | \
    xargs nix show-derivation | jq -r '.[].env | to_entries[] | select(.key | startswith("system")) | .value'

# Build derivation and show what would be downloaded/built
dry-build HOST:
    nix build --dry-run .#nixosConfigurations.{{HOST}}.config.system.build.toplevel

# Check what packages would be added/removed
package-diff HOST:
    @echo "Building new configuration..."
    @nixos-rebuild build --flake .#{{HOST}} > /dev/null 2>&1
    @echo "Comparing package differences..."
    @echo "=== PACKAGES THAT WOULD BE ADDED ==="
    @comm -13 <(nix-store -qR /run/current-system | sort) <(nix-store -qR ./result | sort) | head -20
    @echo ""
    @echo "=== PACKAGES THAT WOULD BE REMOVED ==="
    @comm -23 <(nix-store -qR /run/current-system | sort) <(nix-store -qR ./result | sort) | head -20
    @echo ""
    @echo "Run 'just full-diff {{HOST}}' for complete analysis"

# Comprehensive difference analysis
full-diff HOST:
    #!/usr/bin/env bash
    echo "🔍 Building configuration for comparison..."
    nixos-rebuild build --flake .#{{HOST}}
    echo ""
    echo "📊 STORAGE IMPACT:"
    nix path-info -S ./result
    echo ""
    echo "🔄 CLOSURE DIFFERENCES:"
    nix store diff-closures /run/current-system ./result
    echo ""
    echo "📦 DETAILED PACKAGE ANALYSIS:"
    echo "Current system packages: $(nix-store -qR /run/current-system | wc -l)"
    echo "New system packages: $(nix-store -qR ./result | wc -l)"

# Preview systemd service changes
services-diff HOST:
    #!/usr/bin/env bash
    echo "🔍 Building configuration..."
    nixos-rebuild build --flake .#{{HOST}} > /dev/null 2>&1
    echo ""
    echo "🔄 SYSTEMD SERVICE CHANGES:"
    echo "=== SERVICES THAT WOULD BE ADDED ==="
    comm -13 <(systemctl list-unit-files --state=enabled --no-legend | cut -d' ' -f1 | sort) \
             <(find ./result/etc/systemd/system -name "*.service" -exec basename {} \; 2>/dev/null | sort) | head -10
    echo ""
    echo "=== SERVICES THAT WOULD BE REMOVED ==="  
    comm -23 <(systemctl list-unit-files --state=enabled --no-legend | cut -d' ' -f1 | sort) \
             <(find ./result/etc/systemd/system -name "*.service" -exec basename {} \; 2>/dev/null | sort) | head -10

# === COMPREHENSIVE COMMANDS ===

# Full system validation and build test
full-check HOST:
    @echo "🔍 Running comprehensive validation..."
    just validate
    just check
    just build {{HOST}}
    @echo "✅ All checks passed!"

# Complete deployment workflow
full-deploy HOST:
    @echo "🚀 Starting full deployment workflow..."
    just validate
    just check
    just build {{HOST}}
    just deploy-host {{HOST}}
    @echo "🎉 Deployment complete!"

# System maintenance routine
maintain:
    @echo "🧹 Running system maintenance..."
    just gc
    just optimize
    just check-updates
    @echo "✨ Maintenance complete!"

# Complete safety check workflow
safety-check HOST:
    @echo "🔍 COMPREHENSIVE SAFETY CHECK FOR {{HOST}}"
    @echo "============================================="
    @echo ""
    @echo "1️⃣ Validating configuration syntax..."
    just validate
    @echo ""
    @echo "2️⃣ Checking flake..."
    just check
    @echo ""
    @echo "3️⃣ Analyzing what would change..."
    just diff {{HOST}}
    @echo ""
    @echo "4️⃣ Checking package differences..."
    just package-diff {{HOST}}
    @echo ""
    @echo "5️⃣ Checking service changes..."
    just services-diff {{HOST}}
    @echo ""
    @echo "✅ SAFETY CHECK COMPLETE!"
    @echo "Review the output above, then run:"
    @echo "  • 'just test-run {{HOST}}' for temporary activation"
    @echo "  • 'just deploy-host {{HOST}}' to apply permanently"


