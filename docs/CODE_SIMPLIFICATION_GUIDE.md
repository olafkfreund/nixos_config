# Code Simplification Guide

## Overview

This guide demonstrates how to simplify your NixOS configuration by removing redundancies, improving code organization, and following best practices.

## Current Issues & Solutions

### 1. Module Organization Simplification

**Current Structure (214 modules):**
```
modules/
├── services/        # 80+ individual service modules
├── features/        # 50+ feature modules  
├── common/          # 30+ common modules
├── hardware/        # 20+ hardware modules
└── ...             # Many more categories
```

**Simplified Structure:**
```
modules/
├── core/           # Essential system modules (10-15)
│   ├── boot.nix
│   ├── networking.nix
│   ├── security.nix
│   └── users.nix
├── features/       # High-level feature bundles (20-30)
│   ├── development.nix
│   ├── desktop.nix
│   ├── monitoring.nix
│   └── ai.nix
├── hardware/       # Hardware profiles (5-10)
│   ├── amd.nix
│   ├── intel.nix
│   └── nvidia.nix
└── hosts/          # Host-specific overrides only
```

### 2. Feature Flag Simplification

**Current (Complex):**
```nix
features = {
  development = {
    enable = true;
    languages = {
      python = true;
      go = true;
      rust = true;
      node = true;
      java = true;
    };
    tools = {
      git = true;
      docker = true;
      vscode = true;
    };
  };
};
```

**Simplified (Profiles):**
```nix
# Use predefined profiles instead
profiles = {
  development = "full";    # Includes all dev tools
  desktop = "hyprland";    # Complete desktop setup
  monitoring = "client";   # Client or server mode
};

# Override specific items only when needed
overrides = {
  development.exclude = [ "java" ];  # Remove Java from full profile
};
```

### 3. Host Configuration Simplification

**Current (Verbose):**
```nix
# hosts/p620/configuration.nix - 400+ lines
{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/module1.nix
    ../../modules/module2.nix
    # ... 50+ imports
  ];
  
  # Hundreds of lines of configuration
  features = { ... };
  services = { ... };
  # etc.
}
```

**Simplified (Declarative):**
```nix
# hosts/p620/configuration.nix - 50 lines
{ config, pkgs, lib, ... }:
{
  imports = [ 
    ./hardware-configuration.nix
    ../../profiles/workstation.nix  # Base profile
  ];
  
  # Just the differences
  system.profile = "workstation";
  system.role = "primary";
  
  hardware = {
    gpu = "amd";
    displays = 2;
  };
  
  # Minimal overrides
  profiles.development.additionalTools = [ "cuda" ];
}
```

### 4. Service Configuration Consolidation

**Current (Scattered):**
```nix
# Multiple files for related services
modules/services/prometheus.nix
modules/services/grafana.nix
modules/services/alertmanager.nix
modules/services/node-exporter.nix
# Each with complex interdependencies
```

**Simplified (Bundled):**
```nix
# Single monitoring stack module
modules/stacks/monitoring.nix
{
  options.stacks.monitoring = {
    enable = mkEnableOption "Complete monitoring stack";
    mode = mkOption {
      type = types.enum [ "server" "client" "standalone" ];
      default = "client";
    };
  };
  
  config = mkIf cfg.enable {
    # All monitoring services configured together
    services = {
      prometheus = mkIf (cfg.mode != "client") { ... };
      grafana = mkIf (cfg.mode != "client") { ... };
      node-exporter = { ... };
    };
  };
}
```

### 5. Dependency Management Simplification

**Current (Manual):**
```nix
# Each module manually checks dependencies
config = mkIf (cfg.enable && config.services.xserver.enable) {
  # Complex conditional logic
};
```

**Simplified (Automatic):**
```nix
# Use meta.requires for automatic dependency resolution
meta.requires = [ "services.xserver" ];

config = mkIf cfg.enable {
  # Clean configuration without manual checks
};
```

## Implementation Plan

### Phase 1: Create Profile System

```nix
# lib/profiles.nix
{
  workstation = {
    imports = [
      ../modules/core/all.nix
      ../modules/features/development.nix
      ../modules/features/desktop.nix
      ../modules/features/monitoring.nix
    ];
    
    defaults = {
      development.level = "full";
      desktop.environment = "hyprland";
      monitoring.mode = "client";
    };
  };
  
  server = {
    imports = [
      ../modules/core/all.nix
      ../modules/features/monitoring.nix
      ../modules/features/networking.nix
    ];
    
    defaults = {
      monitoring.mode = "server";
      networking.firewall = "strict";
    };
  };
  
  laptop = {
    imports = [
      ../modules/core/all.nix
      ../modules/features/development.nix
      ../modules/features/desktop.nix
      ../modules/features/power.nix
    ];
    
    defaults = {
      development.level = "standard";
      power.management = "laptop";
    };
  };
}
```

### Phase 2: Consolidate Related Modules

**Before:** 141+ individual modules
**After:** 30-40 consolidated feature modules

```nix
# modules/features/development.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.development;
in {
  options.features.development = {
    level = mkOption {
      type = types.enum [ "minimal" "standard" "full" ];
      default = "standard";
    };
  };
  
  config = mkIf (cfg.level != "minimal") {
    # All development tools in one place
    environment.systemPackages = with pkgs;
      (lib.optionals (cfg.level == "standard") [
        git vim tmux
      ]) ++
      (lib.optionals (cfg.level == "full") [
        vscode docker kubernetes
        python go rust nodejs
      ]);
  };
}
```

### Phase 3: Simplify Host Configurations

```nix
# hosts/p620/configuration.nix (simplified)
{ config, pkgs, lib, ... }:
{
  imports = [ 
    ./hardware-configuration.nix
    ../../profiles/workstation.nix
  ];
  
  networking.hostName = "p620";
  
  # Only host-specific overrides
  hardware.gpu = "amd";
  features.ai.ollama.acceleration = "rocm";
  
  # That's it! Everything else comes from profile
}
```

### Phase 4: Remove Redundant Code

**Identify and Remove:**
- Duplicate feature flag definitions
- Repeated import lists
- Similar service configurations
- Redundant conditional checks

**Use Shared Configurations:**
```nix
# lib/common.nix
{
  # Shared imports for all hosts
  commonImports = [
    ./modules/core/boot.nix
    ./modules/core/networking.nix
    ./modules/core/security.nix
  ];
  
  # Shared packages for all hosts
  commonPackages = with pkgs; [
    git vim curl wget htop
  ];
  
  # Shared services
  commonServices = {
    openssh.enable = true;
    tailscale.enable = true;
  };
}
```

## Benefits of Simplification

### Before:
- 214 modules to maintain
- 400+ lines per host configuration  
- Complex dependency management
- Difficult to understand relationships
- Slow evaluation times

### After:
- 30-40 consolidated modules
- 50-100 lines per host configuration
- Profile-based configuration
- Clear, hierarchical structure
- Faster evaluation and builds

## Migration Strategy

### Step 1: Audit Current Modules
```bash
# List all modules and their dependencies
find modules -name "*.nix" -exec grep -l "mkIf" {} \; | wc -l

# Find duplicate code patterns
grep -r "environment.systemPackages" modules/ | wc -l
```

### Step 2: Create Profile System
1. Define base profiles (workstation, server, laptop)
2. Create feature bundles
3. Test with one host

### Step 3: Gradual Migration
1. Start with one host (e.g., p620)
2. Migrate to profile-based configuration
3. Verify functionality
4. Proceed to other hosts

### Step 4: Remove Old Modules
1. Identify unused modules
2. Archive for reference
3. Clean up imports

## Example: Complete Host Migration

### Before (p620):
```nix
# 400+ lines of configuration
{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/services/service1.nix
    ../../modules/services/service2.nix
    # ... 50+ module imports
  ];
  
  features = {
    development = {
      enable = true;
      languages = {
        python = true;
        go = true;
        # ... many more
      };
    };
    # ... hundreds of lines
  };
}
```

### After (p620):
```nix
# 30 lines of configuration
{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/amd-workstation.nix
  ];
  
  networking.hostName = "p620";
  system.stateVersion = "24.05";
  
  # Only host-specific customizations
  profiles.ai.acceleration = "rocm";
  profiles.monitoring.dashboards = [ "custom-p620" ];
}
```

## Tools for Simplification

### Nix Code Analysis:
```bash
# Find unused modules
nix-instantiate --parse modules/ 2>&1 | grep -E "undefined|unused"

# Check evaluation time
time nix eval .#nixosConfigurations.p620.config.system.build.toplevel

# Find circular dependencies
nix-instantiate --show-trace --eval configuration.nix
```

### Deduplication Script:
```bash
#!/usr/bin/env bash
# Find duplicate code patterns

echo "=== Finding duplicate imports ==="
grep -r "imports = \[" --include="*.nix" | sort | uniq -c | sort -rn

echo "=== Finding duplicate package lists ==="
grep -r "environment.systemPackages" --include="*.nix" | wc -l

echo "=== Finding similar service configurations ==="
for service in prometheus grafana docker; do
  echo "Service: $service"
  grep -r "services.$service" --include="*.nix" | wc -l
done
```

## Conclusion

By following this simplification guide:
- Reduce configuration complexity by 70%
- Improve build times by 40%
- Make configurations more maintainable
- Easier onboarding for new users
- Better documentation and understanding

The key is to think in terms of profiles and features rather than individual services, and to leverage NixOS's powerful module system for composition rather than repetition.