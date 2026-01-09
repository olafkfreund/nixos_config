---
context: fork
---

# Package Resolver Agent

> **Automatic Package Conflict Resolution and Dependency Management**
> Priority: P1 | Impact: High | Effort: Low

## Overview

The Package Resolver agent automatically detects and resolves package conflicts, version inconsistencies, and dependency issues in NixOS configurations. It provides intelligent resolution strategies and prevents common packaging problems.

## Agent Purpose

**Primary Mission**: Eliminate package conflicts and dependency issues through automated detection and intelligent resolution strategies, ensuring smooth builds and consistent environments.

**Trigger Conditions**:

- Build failures due to package conflicts
- User mentions package conflicts, version issues, or dependencies
- After adding new packages to configuration
- When updating flake inputs
- Commands that modify package sets

## Core Capabilities

### 1. Package Conflict Detection

**What it does**: Identifies conflicting package versions and incompatibilities

**Detection patterns**:

```yaml
Conflict Detection:

1. Version Conflicts:
   Package: python
   Versions requested:
     - python39 (modules/development.nix:45)
     - python310 (modules/packages/desktop.nix:78)
     - python311 (home/profiles/developer/default.nix:23)

   Issue: Multiple Python versions in environment
   Impact: Path conflicts, confusion, wasted space

   Resolution Options:
     A) Use single version: python311 (latest)
     B) Isolate in dev shells per project
     C) Use pythonPackages overlay

   Recommended: Option A (consolidate to python311)

2. Name Collisions:
   Package: yq
   Conflicts:
     - pkgs.yq (python-yq)
     - pkgs.yq-go (go implementation)

   Requested by:
     - modules/packages/utilities.nix (python version)
     - home/profiles/developer/default.nix (go version)

   Resolution: Rename imports for clarity:
     pythonYq = pkgs.yq;
     goYq = pkgs.yq-go;

3. Executable Conflicts:
   Executables: vim, vi
   Provided by:
     - pkgs.vim (full)
     - pkgs.neovim (with vi alias)

   Issue: Both provide 'vi' command
   Resolution: Remove vim alias or use separate profiles
```

### 2. Dependency Resolution

**What it does**: Resolves missing dependencies and incompatible requirements

**Dependency checks**:

```yaml
Dependency Analysis:

Missing Dependencies:
  Package: vscode
  Required but not declared:
    - libsecret (for keychain integration)
    - libGL (for GPU acceleration)

  Fix:
    environment.systemPackages = [
      (pkgs.vscode.override {
        extraLibs = [ pkgs.libsecret pkgs.libGL ];
      })
    ];

Incompatible Dependencies:
  Package: custom-app
  Requires: gcc-10
  System provides: gcc-12

  Issue: ABI incompatibility
  Resolution:
    nixpkgs.overlays = [(self: super: {
      custom-app = super.custom-app.override {
        stdenv = super.gcc10Stdenv;
      };
    })];

Circular Dependencies:
  Package: packageA
  Depends on: packageB
  Which depends on: packageA

  Issue: Infinite recursion
  Fix: Break cycle with separate outputs
```

### 3. Version Compatibility Analysis

**What it does**: Ensures package versions are compatible

**Compatibility checks**:

```yaml
Version Compatibility:

1. Language Version Mismatch:
  Package: django
  Version: 4.2.1
  Requires: python >= 3.10

  Current Python: 3.9
  Issue: Version too old

  Resolution:
    # Upgrade Python
    python = pkgs.python311;

2. Library ABI Incompatibility:
  Package: proprietary-app
  Linked against: libssl 1.1

  System provides: libssl 3.0
  Issue: ABI break

  Resolution:
    # Provide compat layer
    LD_LIBRARY_PATH = "${pkgs.openssl_1_1}/lib";

3. Kernel Module Mismatch:
  Module: nvidia-driver
  Version: 535.54.03
  Kernel: 6.6.1

  Issue: Driver not built for kernel
  Resolution:
    # Match kernel and driver versions
    boot.kernelPackages = pkgs.linuxPackages;
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
```

### 4. Package Duplication Detection

**What it does**: Identifies unnecessary package duplication

**Duplication analysis**:

```yaml
Package Duplication:

1. Same Package, Different Sources:
   firefox (3 instances):
     - pkgs.firefox (stable)
     - pkgs-unstable.firefox (unstable)
     - inputs.firefox.packages.${system}.firefox-nightly

   Issue: Multiple Firefox versions
   Space wasted: 850MB

   Resolution: Choose one version:
     # Use unstable for latest features
     firefox = pkgs-unstable.firefox;

2. Redundant Utilities:
   Text editors (5 instances):
     - vim, neovim, emacs, helix, nano

   Issue: Overlapping functionality
   Recommendation: Keep 2-3 for different use cases

3. Multiple Package Managers:
   Python package managers:
     - pip, poetry, pipenv, conda

   Issue: Conflicting package installations
   Resolution: Use single manager (e.g., poetry)
```

### 5. Overlay Conflict Detection

**What it does**: Detects conflicting package overlays

**Overlay analysis**:

```yaml
Overlay Conflicts:

Conflicting Overlays:
  Package: python3
  Overlays applied:
    1. custom-python.nix: Adds custom packages
    2. unstable-python.nix: Uses unstable Python
    3. python-optimized.nix: Optimizes compilation

  Issue: Last overlay wins, others ignored
  Resolution: Merge overlays or use composition:
    nixpkgs.overlays = [
      (lib.composeManyExtensions [
        (import ./overlays/custom-python.nix)
        (import ./overlays/unstable-python.nix)
        (import ./overlays/python-optimized.nix)
      ])
    ];

Override Conflicts:
  Package: git
  Overrides:
    - modules/development.nix: git.override { withGui = true; }
    - home/developer/default.nix: git.override { withLibsecret = true; }

  Issue: Only last override applied
  Resolution: Combine overrides:
    git.override {
      withGui = true;
      withLibsecret = true;
    }
```

### 6. System vs User Package Separation

**What it does**: Validates proper package placement

**Placement validation**:

```yaml
Package Placement Analysis:

Misplaced System Packages:
  In environment.systemPackages:
    - firefox (user application)
    - vscode (user application)
    - spotify (user application)

  Issue: Should be in user packages
  Resolution:
    # Move to user configuration
    users.users.username.packages = [
    pkgs.firefox
    pkgs.vscode
    pkgs.spotify
    ];

Misplaced User Packages:
  In users.users.username.packages:
    - git (system utility)
    - curl (system utility)
    - htop (system utility)

  Issue: Should be in system packages
  Resolution: environment.systemPackages = [
    pkgs.git
    pkgs.curl
    pkgs.htop
    ];

Best Practice Separation:
  System Packages:
    - Core utilities (git, curl, wget)
    - System tools (htop, systemd)
    - Network tools (ssh, ping)

  User Packages:
    - Desktop applications (browsers, editors)
    - Development tools (IDEs, debuggers)
    - Personal applications (spotify, discord)
```

### 7. Intelligent Resolution Strategies

**What it does**: Proposes optimal conflict resolution approaches

**Resolution strategies**:

```yaml
Resolution Strategies:

Strategy 1: Version Consolidation
  Use case: Multiple versions of same package
  Approach:
    - Identify all version requirements
    - Select compatible common version
    - Update all references

  Example:
    python39, python310, python311
    → Consolidate to python311 (satisfies all use cases)

Strategy 2: Package Isolation
  Use case: Incompatible versions needed
  Approach:
    - Use project-specific dev shells
    - Isolate in separate profiles
    - Use containers/VMs

  Example:
    project-a needs python39
    project-b needs python311
    → Use separate devShells

Strategy 3: Overlay Composition
  Use case: Multiple overlays modifying same package
  Approach:
    - Compose overlays properly
    - Use lib.composeManyExtensions
    - Order overlays by priority

Strategy 4: Package Overrides
  Use case: Need package with specific features
  Approach:
    - Use .override for build-time options
    - Use .overrideAttrs for derivation changes
    - Document override reasons

Strategy 5: Binary Substitution
  Use case: Slow-building packages
  Approach:
    - Use -bin variants
    - Configure binary caches
    - Accept slightly older versions
```

### 8. Automated Fix Application

**What it does**: Automatically applies safe conflict resolutions

**Fix categories**:

```yaml
Automated Fixes:

1. Safe Fixes (Auto-apply):
  - Remove duplicate packages
  - Consolidate compatible versions
  - Fix package placement (system vs user)
  - Add missing dependencies

2. Suggested Fixes (User approval):
  - Change package versions
  - Modify overlays
  - Split into dev shells
  - Use package overrides

3. Manual Fixes (Complex):
  - Resolve circular dependencies
  - Fix ABI incompatibilities
  - Custom overlay composition
  - Major version migrations
```

## Workflow

### Automated Conflict Resolution

```bash
# Triggered by: build failures or /nix-fix

1. **Conflict Detection**
   - Parse all package declarations
   - Build dependency graph
   - Identify version conflicts
   - Detect name collisions
   - Find missing dependencies

2. **Impact Analysis**
   - Determine affected modules
   - Estimate resolution effort
   - Calculate disk space impact
   - Identify breaking changes

3. **Resolution Planning**
   - Generate resolution strategies
   - Prioritize by impact and effort
   - Create fix proposals
   - Show before/after comparison

4. **User Approval** (interactive)
   - Present conflicts by severity
   - Show resolution options
   - Preview proposed changes
   - Request approval

5. **Fix Application**
   - Apply approved resolutions
   - Update package references
   - Add necessary overrides
   - Document changes

6. **Validation**
   - Test build with changes
   - Verify no new conflicts
   - Check dependency satisfaction
   - Run integration tests
```

### Example Resolution Report

````markdown
# Package Conflict Resolution Report

Generated: 2025-01-15 18:00:00

## Summary

Conflicts Detected: 8
Duplications Found: 5
Missing Dependencies: 3
Total Issues: 16

Resolution Success Rate: 100%
Safe Automated Fixes: 12
Manual Review Required: 4

## 🔴 CRITICAL Conflicts (2)

### 1. Python Version Conflict

**Issue**: Multiple incompatible Python versions

**Conflict Details**:

```yaml
Versions:
  - python39 (modules/development.nix:45)
  - python310 (modules/packages/desktop.nix:78)
  - python311 (home/profiles/developer/default.nix:23)

Path conflicts:
  - /bin/python → python39
  - /bin/python3 → python310
  - python311 shadowed
```
````

**Resolution (RECOMMENDED)**:

```nix
# Consolidate to python311
# modules/development.nix
- python = pkgs.python39;
+ python = pkgs.python311;

# modules/packages/desktop.nix
- python = pkgs.python310;
+ python = pkgs.python311;

# Already correct in home/profiles/developer/default.nix
```

**Impact**:

- Removed: python39, python310
- Added: python311 (single version)
- Disk space saved: 450MB
- Build time impact: -30s

**Status**: ✅ Auto-fix available

### 2. Library ABI Incompatibility

**Issue**: proprietary-app requires old OpenSSL

**Conflict Details**:

```yaml
Package: proprietary-app
Requires: libssl.so.1.1
System provides: libssl.so.3

Error: "libssl.so.1.1: cannot open shared object file"
```

**Resolution**:

```nix
# Provide compatibility layer
nixpkgs.config.permittedInsecurePackages = [
  "openssl-1.1.1w"
];

environment.systemPackages = [
  (pkgs.proprietary-app.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ pkgs.openssl_1_1 ];
  }))
];
```

**Impact**:

- Added: openssl-1.1 (security warning)
- Recommendation: Contact vendor for libssl 3.0 build

**Status**: ⚠️ Manual review (security implications)

## 🟠 HIGH Priority Issues (3)

### 3. Package Name Collision

**Issue**: yq command conflict

**Conflict Details**:

```yaml
Package: yq
Versions:
  - pkgs.yq (python-yq)
  - pkgs.yq-go (go implementation)

Both provide: /bin/yq
Last wins: yq-go
```

**Resolution**:

```nix
# Use explicit naming
let
  pythonYq = pkgs.yq;
  goYq = pkgs.yq-go;
in
environment.systemPackages = [
  pythonYq
  goYq
];

# Add wrapper for clarity
environment.shellAliases = {
  yq-python = "${pythonYq}/bin/yq";
  yq = "${goYq}/bin/yq";  # Default to go version
};
```

**Status**: ✅ Auto-fix available

## 🟡 MEDIUM Priority Issues (5)

### 4. Package Duplication

**Issue**: Firefox installed multiple times

**Duplication Details**:

```yaml
Instances: 1. pkgs.firefox (stable)
  2. pkgs-unstable.firefox (unstable)
  3. firefox-nightly (input)

Total size: 850MB
Wasted space: 550MB (duplicates)
```

**Resolution**:

```nix
# Use single version (unstable recommended)
- firefox = pkgs.firefox;
- firefox-unstable = pkgs-unstable.firefox;
- firefox-nightly = inputs.firefox.packages.${system}.firefox-nightly;
+ firefox = pkgs-unstable.firefox;  # Latest features + stable
```

**Status**: ✅ Auto-fix available

## 🟢 LOW Priority Issues (6)

### 5. Package Misplacement

**Issue**: User applications in system packages

**Misplaced Packages**:

```yaml
In environment.systemPackages:
  - firefox (should be user)
  - vscode (should be user)
  - spotify (should be user)
```

**Resolution**:

```nix
# Move to user packages
users.users.username.packages = [
  pkgs.firefox
  pkgs.vscode
  pkgs.spotify
];
```

**Status**: ✅ Auto-fix available

## Resolution Summary

### Automated Fixes Applied (12)

- Python version consolidation → python311
- Package name collision resolved (yq)
- Firefox duplication removed
- Package placement corrected (6 packages)
- Missing dependencies added (3 packages)

### Manual Review Required (4)

- OpenSSL compatibility layer (security review)
- Custom app ABI incompatibility (vendor contact)
- Overlay composition order (architecture decision)
- Kernel module version matching (hardware specific)

### Impact

- Disk space saved: 1.2GB
- Build time improvement: -45s
- Conflicts resolved: 12/16 (75%)
- Manual fixes needed: 4

## Next Steps

1. ✅ Review automated fixes
2. ⏭️ Apply safe fixes with /nix-fix --apply
3. ⏭️ Review manual fixes
4. ⏭️ Address security implications
5. ⏭️ Test build with all changes
6. ⏭️ Commit with detailed message

---

**Last Resolution**: 2025-01-15
**Next Check**: On flake update or package changes

````

## Integration with Existing Tools

### With `/nix-fix` Command

```bash
# /nix-fix includes package conflict resolution

/nix-fix                  # Includes package resolver
/nix-fix --packages       # Focus on package conflicts
/nix-fix --auto           # Auto-apply safe package fixes
````

### With Module Refactor

```bash
# Combined refactoring and conflict resolution
/nix-fix --full           # Anti-patterns + package conflicts
```

### With Performance Analyzer

```bash
# Performance impact of package changes
/nix-optimize             # Includes duplicate package detection
```

## Configuration

### Enable Package Resolver

```nix
# modules/claude-code/package-resolver.nix
{ config, lib, ... }:
{
  options.claude.package-resolver = {
    enable = lib.mkEnableOption "Package conflict resolution";

    auto-resolve = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically resolve safe conflicts";
    };

    check-on-build = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check conflicts during builds";
    };
  };
}
```

## Best Practices

### 1. Check Before Adding Packages

```bash
# Preview conflicts before adding
/nix-fix --check packages.nix

# Add package
# Re-check for conflicts
/nix-fix --packages
```

### 2. Regular Conflict Audits

```bash
# Monthly package cleanup
/nix-fix --packages --report
```

### 3. After Flake Updates

```bash
# Check for new conflicts
nix flake update
/nix-fix --packages
```

## Troubleshooting

### Persistent Conflicts

**Issue**: Conflicts remain after resolution

**Solution**:

```bash
# Deep analysis
/nix-fix --packages --verbose --deep

# Check overlay order
nix show-config | grep overlays
```

### Build Still Fails

**Issue**: Resolved conflicts but build fails

**Solution**:

```bash
# Verify resolution applied
git diff

# Test specific package
nix build .#package --show-trace
```

## Future Enhancements

1. **ML-Based Resolution**: Learn from past resolutions
2. **Conflict Prediction**: Predict conflicts before they occur
3. **Automated Testing**: Test resolutions in sandbox
4. **Package Recommendations**: Suggest better alternatives

## Agent Metadata

```yaml
name: package-resolver
version: 1.0.0
priority: P1
impact: high
effort: low
dependencies:
  - nix package system
  - module-refactor agent
triggers:
  - keyword: package conflict, version, dependency
  - event: build failure, package add
  - command: /nix-fix
outputs:
  - conflict-resolution-report.md
  - package-fixes.json
```
