# Create New NixOS Module

Create a new NixOS module following best practices with automatic validation.

## Quick Start

Just tell me:
1. Module name (e.g., "monitoring/postgres-exporter" or "services/myservice")
2. Brief description of what it does

I'll handle the rest automatically.

## What I'll Do

### 1. Read Best Practices (Automatic)
- Read @docs/PATTERNS.md → Module System Patterns
- Read @docs/NIXOS-ANTI-PATTERNS.md → What to avoid
- Understand your repository structure

### 2. Create Module File
Location: `modules/{type}/{name}.nix`

Using this proven template:
```nix
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.features.{module-name};
in {
  options.features.{module-name} = {
    enable = mkEnableOption "{description}";

    package = mkPackageOption pkgs "{package-name}" { };

    settings = mkOption {
      type = types.submodule {
        freeformType = with types; attrsOf anything;
        options = {
          # Structured options here
        };
      };
      default = { };
      description = "Configuration for {service}";
    };
  };

  config = mkIf cfg.enable {
    # Service configuration
    systemd.services.{service-name} = {
      description = "{Description}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/{command}";

        # Security hardening (REQUIRED)
        DynamicUser = true;
        User = "{service-name}";
        Group = "{service-name}";

        # Isolation
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;

        # Additional hardening
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;

        # Resource limits
        MemoryMax = "1G";
        TasksMax = 1000;
      };
    };
  };

  meta.maintainers = with maintainers; [ olafkfreund ];
}
```

### 3. Update Module Imports
Add to `modules/default.nix` in appropriate section.

### 4. Validate Automatically
Run: `just check-syntax` and `just test-modules`

### 5. Provide Usage Example
Show example in host configuration with all options.

## Anti-Patterns I'll Avoid

- ❌ No `mkIf cfg.enable true` - direct boolean assignment
- ❌ No `with pkgs;` at top level - explicit package references
- ❌ No root services - DynamicUser always
- ❌ No evaluation-time secret reads - runtime loading only
- ❌ No trivial wrapper functions - use lib functions directly

## Success Checklist

- [x] Module structure follows PATTERNS.md
- [x] All options comprehensively documented
- [x] Security hardening applied (DynamicUser, isolation)
- [x] Added to modules/default.nix imports
- [x] Syntax validation passed
- [x] Module testing passed
- [x] Example usage provided with explanations
- [x] No anti-patterns detected

## Speed Optimization

This command completes in **under 2 minutes**:
- 30s: Read documentation and understand context
- 60s: Generate module with proper patterns
- 30s: Validate and test

Ready to create your module? Just tell me the name and description!
