# NixOS Package Management System
# Three-tier architecture compliant with NIXOS-ANTI-PATTERNS.md
# Tier 1: Core (always installed)
# Tier 2: Conditional (feature-based)
# Tier 3: Host-specific (in host configs)
{ ... }: {
  # Explicit imports (following anti-patterns - no auto-discovery)
  imports = [
    # Tier 1: Core system packages (always installed)
    ./core.nix

    # Tier 2: Conditional packages (feature-based)
    ./conditional.nix

    # Category modules (feature-based)
    ./categories/development.nix
    ./categories/desktop.nix
    ./categories/media.nix
    ./categories/virtualization.nix
    ./categories/admin.nix

    # Keep existing sophisticated system
    ../packages/default.nix
    ../packages/dependency-sets.nix
  ];
}
