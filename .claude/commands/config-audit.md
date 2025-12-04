# Configuration Audit for NixOS Best Practices

You are a NixOS code quality specialist. Audit the configuration against documented patterns and anti-patterns, identifying improvements.

## Task Overview

Perform comprehensive configuration audit to ensure code quality, security, performance, and adherence to NixOS community standards.

## Audit Scope

This audit checks configurations against:
- @docs/PATTERNS.md - NixOS best practices patterns
- @docs/NIXOS-ANTI-PATTERNS.md - Critical anti-patterns to avoid
- Security hardening standards
- Performance optimization practices
- Code quality and maintainability

## Step 1: Prepare Audit Environment

```bash
# Ensure documentation is up to date
git pull

# Check current status
git status

# Identify files to audit
find . -name "*.nix" -type f | wc -l
echo "Total Nix files to audit: [N]"
```

## Step 2: Anti-Pattern Detection

### 2.1 Check for `mkIf true` Anti-Pattern

```bash
# Search for mkIf true patterns
echo "=== Checking for mkIf true anti-pattern ==="
rg "mkIf\s+\w+\.enable\s+true" --type nix
rg "mkIf\s+\(.*\)\s+true" --type nix

# Should return no results
# If found, these should be converted to direct assignment
```

**Fix pattern:**
```nix
# ❌ Wrong
services.myservice.enable = mkIf cfg.enable true;

# ✅ Correct
services.myservice.enable = cfg.enable;
```

### 2.2 Check for Excessive `with` Usage

```bash
echo "=== Checking for excessive 'with' usage ==="
rg "^with\s+" --type nix | head -20

# Review each instance:
# - Top-level 'with' should be limited
# - 'with pkgs;' in limited scope is OK
# - Multiple nested 'with' statements are problematic
```

**Improvement pattern:**
```nix
# ❌ Wrong - unclear origins
with lib;
with pkgs;
with stdenv;
buildInputs = [ curl jq ];

# ✅ Better - explicit imports
let
  inherit (lib) mkOption mkEnableOption;
  inherit (pkgs) curl jq;
in
buildInputs = [ curl jq ];
```

### 2.3 Check for Dangerous `rec` Usage

```bash
echo "=== Checking for 'rec' attribute sets ==="
rg "rec\s*\{" --type nix

# Review each 'rec' usage:
# - Is it necessary?
# - Could it cause infinite recursion?
# - Can it be replaced with let...in?
```

**Safer pattern:**
```nix
# ❌ Risky - potential infinite recursion
rec {
  a = 1;
  b = a + 1;
  c = let a = c + 1; in a;  # Infinite!
}

# ✅ Safe - explicit references
let
  attrs = {
    a = 1;
    b = attrs.a + 1;
  };
in attrs
```

### 2.4 Check for Import From Derivation (IFD)

```bash
echo "=== Checking for Import From Derivation ==="
rg "import.*\(.*fetch" --type nix
rg "builtins\.readFile.*\(.*fetch" --type nix

# IFD forces build during evaluation
# Should be avoided for performance
```

### 2.5 Check for Unquoted URLs

```bash
echo "=== Checking for unquoted URLs ==="
rg "url\s*=\s*https?://[^\"']" --type nix

# All URLs must be quoted (RFC 45)
```

**Fix:**
```nix
# ❌ Wrong - deprecated
url = https://example.com/file.tar.gz;

# ✅ Correct
url = "https://example.com/file.tar.gz";
```

## Step 3: Security Audit

### 3.1 Check Secret Handling

```bash
echo "=== Checking for secrets in evaluation ==="
rg "builtins\.readFile.*secret" --type nix
rg "builtins\.readFile.*/run/agenix" --type nix
rg "password\s*=\s*\"" --type nix | grep -v "passwordFile"

# Secrets should NEVER be read during evaluation
```

**Correct patterns:**
```nix
# ❌ Wrong - secret in store
services.myservice.password = builtins.readFile "/secrets/password";

# ✅ Correct - runtime loading
services.myservice.passwordFile = "/run/agenix/password";

# ✅ Correct - agenix secret
services.myservice.passwordFile = config.age.secrets.myservice-password.path;
```

### 3.2 Check Service Hardening

```bash
echo "=== Checking systemd service hardening ==="

# Check for services running as root
rg "User\s*=\s*\"root\"" --type nix

# Check for DynamicUser usage
echo "Services with DynamicUser:"
rg "DynamicUser\s*=\s*true" --type nix | wc -l

# Check for security features
echo "Services with ProtectSystem:"
rg "ProtectSystem" --type nix | wc -l
```

**Required hardening pattern:**
```nix
systemd.services.myservice = {
  serviceConfig = {
    # User isolation
    DynamicUser = true;
    User = "myservice";
    Group = "myservice";

    # System protection
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;

    # Privilege restriction
    NoNewPrivileges = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
  };
};
```

### 3.3 Check Firewall Configuration

```bash
echo "=== Auditing firewall rules ==="

# Check if firewall is enabled
rg "networking\.firewall\.enable\s*=\s*false" --type nix

# List all open ports
rg "networking\.firewall\.allowedTCPPorts" --type nix
rg "networking\.firewall\.allowedUDPPorts" --type nix

# Check for trustedInterfaces
rg "networking\.firewall\.trustedInterfaces" --type nix
```

**Review:**
- Is each open port necessary?
- Are ports scoped to specific interfaces?
- Is firewall disabled unnecessarily?

## Step 4: Module System Audit

### 4.1 Check Module Patterns

```bash
echo "=== Auditing module structure ==="

# Find all modules
find modules -name "*.nix" -type f > /tmp/audit-modules.txt

# Check module structure
while read module; do
  echo "Checking: $module"

  # Should have options and config
  grep -q "options\." "$module" && echo "  ✓ Has options"
  grep -q "config\s*=" "$module" && echo "  ✓ Has config"

  # Should use mkIf for conditional config
  grep -q "config\s*=\s*mkIf" "$module" && echo "  ✓ Uses mkIf"

  # Should have enable option
  grep -q "enable\s*=\s*mkEnableOption" "$module" && echo "  ✓ Has enable option"
done < /tmp/audit-modules.txt
```

### 4.2 Check Option Types

```bash
echo "=== Checking option type usage ==="

# Look for proper type usage
rg "mkOption\s*\{" --type nix -A 5 | grep -E "type\s*=" | head -20

# Common issues:
# - Missing type specification
# - Using types.string instead of types.str
# - Not using submodules for structured data
```

**Proper option patterns:**
```nix
options = {
  enable = mkEnableOption "My Service";

  port = mkOption {
    type = types.port;
    default = 8080;
    description = "Port to listen on";
  };

  settings = mkOption {
    type = types.submodule {
      freeformType = with types; attrsOf anything;
      options = {
        host = mkOption {
          type = types.str;
          default = "localhost";
        };
      };
    };
    default = {};
  };
};
```

### 4.3 Check Module Imports

```bash
echo "=== Auditing module imports ==="

# Check for explicit imports (no auto-discovery)
rg "imports\s*=\s*\[" --type nix -A 10

# Look for readDir-based imports (magic auto-discovery)
rg "builtins\.readDir" --type nix
rg "lib\.mapAttrs.*readDir" --type nix

# Should be explicit imports only
```

## Step 5: Package Management Audit

### 5.1 Check for nix-env Usage

```bash
echo "=== Checking for imperative package management ==="

# Search for nix-env references
rg "nix-env" --type nix
rg "nix-env" --type sh

# nix-env should not be used (imperative)
# All packages should be declarative
```

### 5.2 Check Package Organization

```bash
echo "=== Auditing package organization ==="

# System packages
echo "System packages count:"
rg "environment\.systemPackages" --type nix | wc -l

# User packages
echo "User packages count:"
rg "users\.users\..*\.packages" --type nix | wc -l
rg "home\.packages" --type nix | wc -l

# Check for proper separation
```

**Proper organization:**
```nix
# System essentials only
environment.systemPackages = with pkgs; [
  wget curl git vim
];

# User-specific packages
users.users.alice.packages = with pkgs; [
  firefox vscode spotify
];

# Or with Home Manager
home.packages = with pkgs; [
  firefox vscode spotify
];
```

### 5.3 Check Package Derivations

```bash
echo "=== Auditing custom package derivations ==="

# Find custom packages
find pkgs -name "default.nix" -type f 2>/dev/null

# For each package, check:
# - Uses stdenv.mkDerivation or buildNpmPackage/etc
# - Has proper meta attributes
# - Uses strictDeps = true
# - Proper input categorization
```

**Review checklist per package:**
```nix
{ lib, stdenv, fetchFromGitHub, ... }:

stdenv.mkDerivation rec {
  pname = "my-package";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "sha256-...";  # ✓ Hash provided
  };

  strictDeps = true;  # ✓ Strict deps enabled

  nativeBuildInputs = [ ];  # Build-time tools
  buildInputs = [ ];        # Runtime deps

  meta = with lib; {
    description = "...";    # ✓ Description
    homepage = "...";       # ✓ Homepage
    license = licenses.mit; # ✓ License
    maintainers = [ ];      # ✓ Maintainers
    platforms = platforms.linux;  # ✓ Platforms
  };
}
```

## Step 6: Performance Audit

### 6.1 Check Garbage Collection

```bash
echo "=== Checking garbage collection configuration ==="

rg "nix\.gc" --type nix -A 5

# Should have automated GC configured
```

**Required:**
```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

### 6.2 Check Binary Cache Configuration

```bash
echo "=== Auditing binary cache setup ==="

rg "nix\.settings\.substituters" --type nix
rg "nix\.settings\.trusted-public-keys" --type nix

# Verify public keys are correct
```

### 6.3 Check Build Optimization

```bash
echo "=== Checking build optimization settings ==="

rg "nix\.settings\.max-jobs" --type nix
rg "nix\.settings\.cores" --type nix
rg "nix\.settings\.sandbox" --type nix
```

## Step 7: Code Quality Audit

### 7.1 Check for Code Duplication

```bash
echo "=== Identifying code duplication ==="

# Find repeated configuration blocks
# This requires manual review of similar files

# Compare host configurations
diff -u hosts/p620/configuration.nix hosts/razer/configuration.nix | grep -E "^[+-]" | head -20

# Look for extractable patterns
```

### 7.2 Check Documentation

```bash
echo "=== Checking documentation completeness ==="

# Options should have descriptions
rg "mkOption\s*\{" --type nix -A 10 | grep -c "description"

# Modules should have documentation
find modules -name "*.nix" | while read f; do
  grep -q "description.*=.*\"" "$f" || echo "Missing docs: $f"
done
```

### 7.3 Check for TODO/FIXME

```bash
echo "=== Finding TODO and FIXME comments ==="

rg "TODO|FIXME|XXX|HACK" --type nix -n

# Each should be:
# - Documented in GitHub issues
# - Have assigned priority
# - Have timeline for resolution
```

## Step 8: Generate Audit Report

Create comprehensive audit report:

```markdown
# NixOS Configuration Audit Report
**Date:** $(date +%Y-%m-%d)
**Auditor:** Claude Code Configuration Auditor

## Executive Summary

- Total Nix files audited: [N]
- Anti-patterns found: [N]
- Security issues: [N]
- Performance concerns: [N]
- Code quality issues: [N]

**Overall Score:** [X/100]

## Anti-Pattern Detection

### 🔴 Critical Anti-Patterns (Must Fix)

1. **mkIf true Pattern**
   - Instances found: [N]
   - Files affected: [list]
   - Fix: Use direct boolean assignment
   - Example: [file:line]

2. **Evaluation-Time Secret Reading**
   - Instances found: [N]
   - Files affected: [list]
   - Fix: Use passwordFile or runtime loading
   - Security impact: HIGH

[Continue for each critical anti-pattern]

### 🟡 Code Quality Issues (Should Fix)

1. **Excessive 'with' Usage**
   - Instances: [N]
   - Impact: Code clarity
   - Recommendation: Use explicit imports

[Continue for each quality issue]

## Security Audit

### 🔒 Security Findings

#### Secrets Management
- ✅ Properly using agenix: [Yes/No]
- ❌ Secrets in evaluation: [N instances]
- ✅ Runtime secret loading: [N services]

#### Service Hardening
- Services with DynamicUser: [N/Total]
- Services with ProtectSystem: [N/Total]
- Services running as root: [N] ⚠️

#### Firewall Configuration
- Firewall enabled: [Yes/No]
- Open TCP ports: [list]
- Open UDP ports: [list]
- Unnecessary ports: [list if any]

## Module System Review

### Module Quality
- Modules with proper structure: [N/Total]
- Modules with enable options: [N/Total]
- Modules with type specifications: [N/Total]
- Modules with descriptions: [N/Total]

### Import Strategy
- Using explicit imports: ✅/❌
- Magic auto-discovery found: [N instances]

## Package Management

### Organization
- System packages: [N]
- User packages: [N]
- Proper separation: ✅/❌

### Custom Derivations
- Total custom packages: [N]
- Packages following patterns: [N/Total]
- Packages with complete meta: [N/Total]
- Packages with strictDeps: [N/Total]

## Performance Analysis

### Build Optimization
- Garbage collection: [Configured/Not configured]
- Binary caches: [N configured]
- Build parallelization: [Settings]

### Evaluation Performance
- IFD usage: [N instances]
- Excessive evaluation: [Concerns if any]

## Code Quality Metrics

### Documentation
- Options with descriptions: [N%]
- Modules with documentation: [N%]
- README completeness: [Score]

### Maintainability
- Code duplication level: [Low/Medium/High]
- Average file complexity: [Score]
- TODO/FIXME items: [N]

## Recommendations

### 🔴 Critical (Fix Immediately)

1. **[Issue]**
   - File: [path:line]
   - Fix: [specific action]
   - Command: `[exact command to fix]`

[Continue for each critical item]

### 🟡 High Priority (Fix This Week)

1. **[Issue]**
   - File: [path:line]
   - Fix: [specific action]
   - Command: `[exact command to fix]`

[Continue for each high priority item]

### 🟢 Medium Priority (Fix This Month)

1. **[Issue]**
   - Recommendation: [action]
   - Benefit: [expected improvement]

[Continue for each medium priority item]

### ⚪ Low Priority (Consider)

1. **[Suggestion]**
   - Context: [explanation]
   - Optional improvement: [suggestion]

[Continue for suggestions]

## Action Plan

### Immediate Actions (Today)
- [ ] Fix critical anti-pattern at [file:line]
- [ ] Address security issue in [file:line]
- [ ] [Additional critical items]

### This Week
- [ ] Implement service hardening for [services]
- [ ] Add proper types to [modules]
- [ ] [Additional high priority items]

### This Month
- [ ] Reduce code duplication in [area]
- [ ] Improve documentation for [modules]
- [ ] [Additional medium priority items]

## Compliance Score

| Category | Score | Status |
|----------|-------|--------|
| Anti-patterns | X/100 | 🟢/🟡/🔴 |
| Security | X/100 | 🟢/🟡/🔴 |
| Module System | X/100 | 🟢/🟡/🔴 |
| Package Mgmt | X/100 | 🟢/🟡/🔴 |
| Performance | X/100 | 🟢/🟡/🔴 |
| Code Quality | X/100 | 🟢/🟡/🔴 |

**Overall Score:** X/100

## Next Audit

Schedule next audit for: [Date + 30 days]

## References

- @docs/PATTERNS.md
- @docs/NIXOS-ANTI-PATTERNS.md
- @.agent-os/product/tech-stack.md
```

## Step 9: Create GitHub Issues for Findings

For each critical/high priority finding:

```bash
/new_task

# Create issue for each major finding
# Type: refactor or fix
# Priority: based on severity
# Title: "[Audit] Fix [specific anti-pattern]"
# Description: Reference audit report section
```

## Step 10: Track Progress

```bash
# Save audit report
mkdir -p docs/audits
mv audit-report.md docs/audits/audit-$(date +%Y-%m-%d).md

# Create audit tracking issue
/new_task
# Title: "Configuration Audit $(date +%Y-%m-%d) - Track Improvements"
# Link to all sub-issues created

# Schedule next audit
echo "Next audit due: $(date -d '+30 days' +%Y-%m-%d)" >> docs/scheduled-tasks.txt
```

## Success Criteria

- [ ] All Nix files scanned for anti-patterns
- [ ] Security audit completed
- [ ] Module system reviewed
- [ ] Package management assessed
- [ ] Performance optimization checked
- [ ] Code quality evaluated
- [ ] Comprehensive report generated
- [ ] Critical issues identified
- [ ] GitHub issues created for findings
- [ ] Action plan established
- [ ] Next audit scheduled

## Monitoring Progress

```bash
# Track improvement over time
echo "Audit scores:" >> docs/audits/scores.log
echo "$(date +%Y-%m-%d): [score]" >> docs/audits/scores.log

# Compare with previous audit
diff docs/audits/audit-[PREV-DATE].md docs/audits/audit-$(date +%Y-%m-%d).md
```

## Notes

- Run audit monthly or after major changes
- Use audit findings to improve patterns documentation
- Share learnings with NixOS community
- Track metrics to measure improvement
- Prioritize security and anti-patterns first

## Example Workflow

```bash
# 1. Run complete audit
/config-audit

# 2. Review generated report
cat docs/audits/audit-$(date +%Y-%m-%d).md

# 3. Create issues for critical findings
/new_task  # For each critical item

# 4. Fix immediate critical issues
# [Work on critical fixes]

# 5. Schedule follow-up work
# [Create plan for high/medium items]

# 6. Track progress
/check_tasks  # Review audit-related issues

# 7. Schedule next audit
echo "Next audit: $(date -d '+30 days')" >> calendar
```
