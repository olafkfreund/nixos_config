# Module Refactor Agent

> **Intelligent Code Refactoring and Anti-Pattern Detection for NixOS Modules**
> Priority: P1 | Impact: High | Effort: Medium

## Overview

The Module Refactor agent automatically detects code duplication, anti-patterns, and refactoring opportunities across NixOS modules. It provides automated fixes, suggests architectural improvements, and helps maintain code quality standards.

## Agent Purpose

**Primary Mission**: Maintain high code quality through automated detection of anti-patterns, code duplication, and refactoring opportunities, with intelligent fix suggestions aligned with NixOS best practices.

**Trigger Conditions**:

- User mentions refactoring, cleanup, or code quality
- Commands like `/nix-fix` or `/nix-review`
- After adding new modules
- Before major releases
- Weekly code quality audits (if configured)

## Core Capabilities

### 1. Anti-Pattern Detection

**What it does**: Scans all Nix files for anti-patterns from docs/NIXOS-ANTI-PATTERNS.md

**Detection categories**:

```yaml
Anti-Pattern Categories:

1. mkIf true Pattern (CRITICAL):
   Pattern: mkIf condition true
   Fix: Direct boolean assignment
   Instances: 0 (target achieved ✅)

2. Excessive 'with' Usage (HIGH):
   Pattern: Multiple nested 'with' statements
   Fix: Explicit imports with limited scope
   Instances: 15 detected

3. Dangerous 'rec' Usage (HIGH):
   Pattern: rec { ... } with self-reference
   Fix: Explicit let bindings
   Instances: 3 detected

4. Import From Derivation (CRITICAL):
   Pattern: Evaluation-time builds
   Fix: Separate evaluation and building
   Instances: 0 (good! ✅)

5. Evaluation-Time Secret Reading (CRITICAL):
   Pattern: builtins.readFile for secrets
   Fix: Runtime loading with passwordFile
   Instances: 0 (secure ✅)

6. Trivial Function Wrappers (MEDIUM):
   Pattern: Unnecessary abstraction layers
   Fix: Direct function calls
   Instances: 8 detected
```

### 2. Code Duplication Detection

**What it does**: Identifies repeated code patterns and suggests extraction

**Duplication analysis**:

```yaml
Code Duplication Report:

Duplicated Patterns:

1. Systemd Service Hardening (12 instances):
   Files affected:
     - modules/services/prometheus.nix
     - modules/services/grafana.nix
     - modules/services/loki.nix
     - ... (9 more)

   Repeated code:
     systemd.services.SERVICE.serviceConfig = {
       DynamicUser = true;
       ProtectSystem = "strict";
       ProtectHome = true;
       NoNewPrivileges = true;
     };

   Recommendation:
     Extract to lib/systemd-hardening.nix:
       mkHardenedService = name: config: {
         serviceConfig = {
           DynamicUser = true;
           ProtectSystem = "strict";
           ProtectHome = true;
           NoNewPrivileges = true;
         } // config;
       };

   Impact: 48 lines → 12 lines (75% reduction)

2. Package List Patterns (8 instances):
   Files affected:
     - modules/packages/categories/development.nix
     - modules/packages/categories/desktop.nix
     - ... (6 more)

   Repeated pattern:
     environment.systemPackages = with pkgs; [ ... ];

   Recommendation:
     Use package sets with composition:
       packageSets.development ++ packageSets.desktop

   Impact: Better organization, easier maintenance

3. Feature Flag Boilerplate (141 instances):
   Pattern:
     options.features.NAME = {
       enable = mkEnableOption "NAME";
     };
     config = mkIf cfg.enable { ... };

   Status: Template pattern (acceptable)
   Note: This is intentional architecture, not duplication
```

### 3. Module Structure Analysis

**What it does**: Validates module architecture and organization

**Structural checks**:

```yaml
Module Structure Validation:

File Organization:
  ✅ All services in modules/services/
  ✅ All features in modules/features/
  ✅ All packages in modules/packages/
  ⚠️ 3 modules in wrong directory

Import Structure:
  ✅ Explicit imports in modules/default.nix
  ✅ No auto-discovery patterns
  ❌ 5 circular import dependencies detected

Naming Conventions:
  ✅ 138/141 modules follow naming standard
  ⚠️ 3 modules use inconsistent names:
      - modules/misc/temp-fix.nix (non-descriptive)
      - modules/old-monitoring.nix (deprecated)
      - modules/test.nix (test file in production)

Module Size:
  ✅ Average: 85 lines
  ⚠️ Large modules (>200 lines):
      - modules/desktop/hyprland/default.nix (450 lines)
        Recommendation: Split into submodules

Documentation:
  ✅ 95% modules have option descriptions
  ⚠️ 7 modules missing descriptions
```

### 4. Type System Validation

**What it does**: Ensures proper NixOS type usage

**Type validation**:

```yaml
Type System Analysis:

Type Correctness:
  ✅ 95% options use correct types
  ⚠️ Type issues detected:

1. Loose typing (5 instances):
   Location: modules/features/development.nix:45
   Current: type = types.attrs;
   Issue: Too permissive, no validation
   Fix: Use structured submodule:
     type = types.submodule {
       options = {
         python = mkEnableOption "Python";
         go = mkEnableOption "Go";
         rust = mkEnableOption "Rust";
       };
     };

2. Missing defaults (8 instances):
   Location: modules/services/myservice.nix:23
   Current: option without default
   Issue: Forces users to set value
   Fix: Add sensible default:
     default = 8080;

3. Incorrect merge behavior (2 instances):
   Location: modules/packages/sets.nix:67
   Current: type = types.listOf types.package;
   Issue: Lists don't merge well
   Fix: Use attrsOf for better merging:
     type = types.attrsOf types.package;
```

### 5. Dependency Analysis

**What it does**: Maps module dependencies and detects issues

**Dependency graph**:

```yaml
Module Dependencies:

Circular Dependencies (HIGH PRIORITY):
  1. modules/desktop/hyprland.nix
     → modules/desktop/wayland.nix
     → modules/desktop/hyprland.nix

     Fix: Extract shared functionality to
          modules/desktop/common.nix

  2. modules/monitoring/prometheus.nix
     → modules/monitoring/exporters.nix
     → modules/monitoring/prometheus.nix

     Fix: Split exporters into independent modules

Heavy Dependencies (REVIEW):
  modules/features/desktop.nix depends on:
    - gnome (15 submodules)
    - hyprland (12 submodules)
    - plasma (10 submodules)

  Recommendation: Use lazy loading pattern
    imports = lib.optionals cfg.gnome.enable [
      ./desktop/gnome
    ];

Unused Modules:
  - modules/old-monitoring.nix (deprecated)
  - modules/test.nix (test file)

  Recommendation: Remove from imports
```

### 6. Security Pattern Analysis

**What it does**: Validates security best practices in modules

**Security checks**:

```yaml
Security Pattern Validation:

Service Hardening:
  ✅ 45/48 services use DynamicUser
  ⚠️ 3 services need hardening:
      - modules/services/legacy-app.nix
      - modules/services/custom-daemon.nix
      - modules/services/testing-service.nix

Secret Management:
  ✅ All secrets use runtime loading
  ✅ No evaluation-time secret reads
  ✅ Agenix integration correct

Firewall Configuration:
  ✅ All services declare firewall needs
  ⚠️ 2 services have overly permissive rules:
      - modules/services/dev-server.nix (all ports)
      - modules/services/testing.nix (no restrictions)

User Permissions:
  ✅ No services run as root
  ✅ All use dedicated users or DynamicUser
  ✅ Proper group memberships
```

### 7. Performance Pattern Detection

**What it does**: Identifies performance anti-patterns

**Performance checks**:

```yaml
Performance Analysis:

Evaluation Performance:
  ✅ No Import From Derivation (IFD)
  ⚠️ Heavy evaluation patterns:

1. Excessive recursion (2 instances):
   Location: modules/packages/sets.nix:123
   Pattern: Recursive attribute set generation
   Impact: Slow evaluation (3s)
   Fix: Pre-compute or use explicit definitions

2. Large list operations (5 instances):
   Location: modules/features/development.nix:78
   Pattern: map/filter on 100+ item lists
   Impact: Evaluation overhead
   Fix: Use attribute sets for O(1) lookup

Build Performance:
  ✅ No unnecessary rebuilds
  ⚠️ Inefficient patterns:

1. Missing binary substitutes:
   - 15 packages built from source unnecessarily
   Fix: Use -bin variants where available

2. Duplicate package versions:
   - python39 and python310 both included
   Fix: Consolidate to single version
```

### 8. Automated Fix Generation

**What it does**: Generates fixes for detected issues

**Fix categories**:

```yaml
Automated Fixes Available:

1. Critical Fixes (Auto-apply safe):
   - Remove 'mkIf condition true' (0 instances)
   - Fix evaluation-time secret reads (0 instances)
   - Remove Import From Derivation (0 instances)

2. High Priority Fixes (Review recommended):
   - Reduce excessive 'with' usage (15 instances)
   - Fix dangerous 'rec' usage (3 instances)
   - Add missing service hardening (3 instances)

3. Code Quality Fixes (Optional):
   - Remove trivial wrappers (8 instances)
   - Extract duplicated code (12 patterns)
   - Improve type definitions (5 instances)

4. Organizational Fixes (Manual):
   - Resolve circular dependencies (2 instances)
   - Move misplaced modules (3 instances)
   - Remove unused modules (2 instances)
```

## Workflow

### Automated Refactoring Process

```bash
# Triggered by: /nix-fix or /nix-review

1. **Code Scanning**
   - Parse all .nix files
   - Build syntax tree (AST)
   - Index all definitions
   - Map dependencies

2. **Pattern Detection**
   - Scan for anti-patterns
   - Identify code duplication
   - Check type correctness
   - Validate security patterns
   - Analyze performance

3. **Issue Prioritization**
   🔴 CRITICAL: Security, IFD, evaluation-time secrets
   🟠 HIGH: Anti-patterns, circular dependencies
   🟡 MEDIUM: Code quality, duplication
   🟢 LOW: Style, organization

4. **Fix Generation**
   - Generate automated fixes
   - Create before/after diffs
   - Estimate impact and risk
   - Group related fixes

5. **User Review** (interactive)
   - Present findings by priority
   - Show fix previews
   - Request approval per fix group
   - Allow selective application

6. **Fix Application**
   - Apply approved fixes
   - Run syntax validation
   - Test with nix build
   - Commit changes with details

7. **Validation**
   - Verify syntax correctness
   - Test module loading
   - Check for regressions
   - Update documentation
```

### Example Refactoring Report

```markdown
# Module Refactoring Report
Generated: 2025-01-15 17:15:00
Modules Analyzed: 141

## Executive Summary

Code Quality: Good (8.5/10)
Anti-Patterns: 26 instances detected
Duplication: 12 patterns identified
Security: Excellent (9.5/10)
Performance: Good (8/10)

Refactoring Recommendations: 18 fixes
Estimated Impact: 15% code reduction
Effort Required: 2-3 hours

## 🔴 CRITICAL Issues (0)

✅ No critical issues detected!

## 🟠 HIGH Priority Issues (18)

### 1. Excessive 'with' Usage (15 instances)

**Example (modules/packages/development.nix:45)**:
```nix
# ❌ BEFORE - Unclear variable origins
with pkgs; with lib; with stdenv;
buildInputs = [ curl jq python3 ];

# ✅ AFTER - Explicit and clear
let
  inherit (pkgs) curl jq python3;
in
buildInputs = [ curl jq python3 ];
```

**Impact**: Improved code clarity and maintainability
**Effort**: 5 minutes per instance
**Auto-fix**: ✅ Available

**Files affected**:
- modules/packages/development.nix (5 instances)
- modules/packages/desktop.nix (4 instances)
- modules/features/gaming.nix (3 instances)
- modules/features/virtualization.nix (3 instances)

**Fix command**:
```bash
/nix-fix --apply excessive-with
```

### 2. Dangerous 'rec' Usage (3 instances)

**Example (modules/lib/helpers.nix:23)**:
```nix
# ❌ BEFORE - Risk of infinite recursion
rec {
  a = 1;
  b = a + 1;
  c = let a = a + 1; in a;  # Infinite loop!
}

# ✅ AFTER - Explicit and safe
let
  helpers = {
    a = 1;
    b = helpers.a + 1;
    c = helpers.a + 1;
  };
in helpers
```

**Impact**: Prevents infinite recursion bugs
**Effort**: 10 minutes per instance
**Auto-fix**: ✅ Available

### 3. Missing Service Hardening (3 instances)

**Example (modules/services/legacy-app.nix)**:
```nix
# ❌ BEFORE - No security hardening
systemd.services.legacy-app = {
  serviceConfig = {
    ExecStart = "${pkgs.legacy-app}/bin/legacy-app";
  };
};

# ✅ AFTER - Properly hardened
systemd.services.legacy-app = {
  serviceConfig = {
    ExecStart = "${pkgs.legacy-app}/bin/legacy-app";
    DynamicUser = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectKernelTunables = true;
  };
};
```

**Impact**: Improved security posture
**Effort**: 5 minutes per service
**Auto-fix**: ✅ Available

**Services needing hardening**:
- modules/services/legacy-app.nix
- modules/services/custom-daemon.nix
- modules/services/testing-service.nix

## 🟡 MEDIUM Priority Issues (12)

### 4. Code Duplication - Systemd Hardening Pattern

**Detected in 12 modules**

```nix
# Current: Repeated in 12 files (48 lines total)
systemd.services.SERVICE.serviceConfig = {
  DynamicUser = true;
  ProtectSystem = "strict";
  ProtectHome = true;
  NoNewPrivileges = true;
};

# Proposed: Extract to lib/systemd-hardening.nix
# Usage: mkHardenedService "serviceName" { ... }
```

**Impact**: 75% code reduction (48 → 12 lines)
**Effort**: 30 minutes (create lib + update modules)
**Auto-fix**: ⚠️ Manual (architectural change)

### 5. Trivial Function Wrappers (8 instances)

**Example (modules/lib/package-helpers.nix:67)**:
```nix
# ❌ BEFORE - Unnecessary wrapper
installPackage = pkg: [ pkg ];

# ✅ AFTER - Direct usage
# Just use: [ package ]
```

**Impact**: Reduced complexity
**Effort**: 2 minutes per instance
**Auto-fix**: ✅ Available

## 🟢 LOW Priority Issues (8)

### 6. Inconsistent Module Naming

**Modules with non-standard names**:
- modules/misc/temp-fix.nix → modules/fixes/boot-delay.nix
- modules/old-monitoring.nix → DELETE (deprecated)
- modules/test.nix → DELETE (test file)

**Impact**: Better organization
**Effort**: 10 minutes
**Auto-fix**: ⚠️ Manual (file moves)

## Recommended Fix Sequence

### Phase 1: Automated Fixes (30 minutes)
```bash
# Apply all safe automated fixes
/nix-fix --apply all-safe

# This will fix:
# - Excessive 'with' usage (15 instances)
# - Dangerous 'rec' usage (3 instances)
# - Missing service hardening (3 instances)
# - Trivial function wrappers (8 instances)
```

### Phase 2: Code Extraction (1 hour)
```bash
# Extract systemd hardening pattern
1. Create lib/systemd-hardening.nix
2. Update 12 service modules
3. Test all affected services
```

### Phase 3: Organizational Cleanup (30 minutes)
```bash
# Rename and remove modules
1. Rename temp-fix.nix → boot-delay.nix
2. Delete old-monitoring.nix
3. Delete test.nix
4. Update imports in modules/default.nix
```

### Phase 4: Validation (30 minutes)
```bash
# Verify all changes
just check-syntax      # Syntax validation
just test-all-parallel # Build test all hosts
just validate          # Full validation
```

## Total Impact

**Code Changes**:
- Lines removed: 85
- Lines added: 35
- Net reduction: 50 lines (3.5%)

**Quality Improvements**:
- Anti-patterns eliminated: 26 → 0
- Code duplication: 75% reduction
- Security coverage: 94% → 100%

**Effort Required**:
- Automated fixes: 30 minutes
- Manual refactoring: 1.5 hours
- Testing: 30 minutes
- Total: 2.5 hours

## Next Steps

1. ✅ Review this report
2. ⏭️ Apply automated fixes with /nix-fix
3. ⏭️ Create systemd hardening library
4. ⏭️ Update affected modules
5. ⏭️ Run full validation suite
6. ⏭️ Commit with detailed message

---

**Last Refactoring**: 2025-01-15
**Next Review**: 2025-02-15 (monthly)
```

## Integration with Existing Tools

### With `/nix-fix` Command

```bash
# /nix-fix uses module-refactor for detection and fixes

/nix-fix                  # Interactive refactoring
/nix-fix --auto          # Auto-apply safe fixes
/nix-fix --preview       # Preview changes only
/nix-fix --type=anti-patterns  # Focus on specific issues
```

### With `/nix-review` Command

```bash
# /nix-review includes refactoring analysis

/nix-review              # Code review with refactoring
# Checks for anti-patterns before approval
# Blocks merge if critical issues found
```

### With Security Patrol

```bash
# Combined security and code quality
Security Patrol detects:
  - Missing service hardening
  - Insecure patterns

Module Refactor suggests:
  - Proper systemd hardening
  - Code structure improvements
```

### With Performance Analyzer

```bash
# Combined performance and code quality
Performance Analyzer identifies:
  - Slow evaluation patterns
  - Build performance issues

Module Refactor suggests:
  - Refactoring for better performance
  - Removing evaluation overhead
```

## Configuration

### Enable Module Refactor

```nix
# modules/claude-code/module-refactor.nix
{ config, lib, ... }:
{
  options.claude.module-refactor = {
    enable = lib.mkEnableOption "Module refactoring and code quality";

    auto-fix = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically apply safe fixes";
    };

    check-on-build = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check code quality during builds";
    };

    block-anti-patterns = lib.mkOption {
      type = lib.types.enum [ "none" "critical" "high" "all" ];
      default = "critical";
      description = "Block builds on anti-pattern detection";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "monthly";
      description = "Automated code quality review schedule";
    };
  };

  config = lib.mkIf config.claude.module-refactor.enable {
    # Code quality checks in build process
    system.activationScripts.code-quality-check = lib.mkIf config.claude.module-refactor.check-on-build ''
      echo "Running code quality checks..."
      # Check for anti-patterns
    '';
  };
}
```

## Best Practices

### 1. Regular Refactoring Sessions

```bash
# Monthly code quality review
/nix-fix --report

# Apply fixes incrementally
/nix-fix --apply safe
```

### 2. Pre-Commit Refactoring

```bash
# Check before committing
/nix-review

# Fix issues found
/nix-fix --auto
```

### 3. After Adding Modules

```bash
# Check new module quality
/nix-fix --file modules/services/newservice.nix

# Ensure consistency
/nix-review modules/services/
```

## Troubleshooting

### False Positives

**Issue**: Module-refactor flags correct code as problematic

**Solution**:
```nix
# Add exceptions in configuration
claude.module-refactor.exceptions = [
  "modules/legacy/special-case.nix"  # Has valid reason for pattern
];
```

### Automated Fixes Break Code

**Issue**: Applied fixes cause build failures

**Solution**:
```bash
# Revert specific fix
git revert HEAD

# Report issue for fix improvement
/nix-new-task
# Title: "module-refactor: Fix XYZ breaks build"
```

### Large Refactoring Effort

**Issue**: Too many issues to fix at once

**Solution**:
```bash
# Prioritize critical issues only
/nix-fix --priority=critical

# Fix incrementally over time
/nix-fix --limit=5  # Fix 5 issues per session
```

## Future Enhancements

### Planned Features

1. **AI-Powered Refactoring**: ML-based pattern detection
2. **Refactoring Templates**: Common refactoring patterns library
3. **Impact Analysis**: Predict refactoring impact before applying
4. **Refactoring Metrics**: Track code quality over time
5. **Integration with IDEs**: Real-time refactoring suggestions
6. **Automated Testing**: Generate tests for refactored code

## Resources

### Documentation References

- **Anti-Patterns**: docs/NIXOS-ANTI-PATTERNS.md
- **Best Practices**: docs/PATTERNS.md

### External Resources

- [Nix Language Anti-Patterns](https://nix.dev/anti-patterns)
- [NixOS Module System](https://nixos.org/manual/nixos/stable/#sec-writing-modules)

## Agent Metadata

```yaml
name: module-refactor
version: 1.0.0
priority: P1
impact: high
effort: medium
dependencies:
  - docs/NIXOS-ANTI-PATTERNS.md
  - docs/PATTERNS.md
  - nix-check agent
triggers:
  - keyword: refactor, cleanup, code quality, anti-pattern
  - command: /nix-fix, /nix-review
  - event: new module added
  - schedule: monthly
outputs:
  - refactoring-report.md
  - code-quality-metrics.json
  - fix-patches/
```
