# Conditional Feature Packages - Tier 2
# Packages enabled based on host capabilities and feature flags
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, ... }:
let
  cfg = config.features;
  # Import existing package sets to avoid duplication
  packageSets = import ../packages/sets.nix { inherit pkgs lib; };
in
{
  config = {
    environment.systemPackages = with pkgs; [
      # Base packages - always included
    ]
    # Development packages - NO mkIf condition true!
    ++ lib.optionals (cfg.development.enable or false) packageSets.development.common
    ++ lib.optionals (cfg.development.python or false) packageSets.development.python
    ++ lib.optionals (cfg.development.nodejs or false) packageSets.development.nodejs
    ++ lib.optionals (cfg.development.rust or false) packageSets.development.rust
    ++ lib.optionals (cfg.development.go or false) packageSets.development.go
    ++ lib.optionals (cfg.development.lua or false) packageSets.development.lua
    ++ lib.optionals (cfg.development.nix or false) packageSets.development.nix

    # Virtualization packages
    ++ lib.optionals (cfg.virtualization.docker or false) packageSets.virtualization.docker
    ++ lib.optionals (cfg.virtualization.vm or false) packageSets.virtualization.vm
    ++ lib.optionals (cfg.virtualization.kubernetes or false) packageSets.virtualization.kubernetes

    # Cloud tools
    ++ lib.optionals (cfg.cloud.aws or false) packageSets.cloud.aws
    ++ lib.optionals (cfg.cloud.azure or false) packageSets.cloud.azure
    ++ lib.optionals (cfg.cloud.terraform or false) packageSets.cloud.terraform

    # Security tools (headless-compatible)
    ++ lib.optionals (cfg.security.enable or false) packageSets.security

    # Network tools (headless-compatible)
    ++ lib.optionals (cfg.network.enable or false) packageSets.network

    # Monitoring tools (headless-compatible)
    ++ lib.optionals (cfg.monitoring.enable or false) packageSets.monitoring;
  };
}
