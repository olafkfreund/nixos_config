# NixOS Validation Suite

Comprehensive validation of NixOS configurations with multiple modes for different use cases.

**Replaces Justfile recipes**: `validate`, `validate-quick`, `validate-quality`, `validate-full`, `check`, `check-syntax`, `check-updates`, `check-deprecated`, `security-scan`, `test-rollback`

## Quick Usage

**Quick validation** (30 seconds):

```
/nix-validate
Quick validation
```

**Standard validation** (1 minute):

```
/nix-validate
```

**Full validation** (2 minutes):

```
/nix-validate
Full validation
```

**Specific checks**:

```
/nix-validate
Syntax check only

/nix-validate
Security scan only

/nix-validate
Check for deprecated options
```

## Features

### Validation Levels

**Quick Mode** (~30 seconds):

- ✅ Syntax validation (`nix flake check --no-build`)
- ✅ Basic feature validation
- ✅ Fast feedback for development

**Standard Mode** (~1 minute):

- ✅ Everything in Quick mode
- ✅ Feature dependency validation (`lib.validateFeatures`)
- ✅ Security configuration checks (`lib.validateSecurity`)
- ✅ Module structure validation

**Full Mode** (~2 minutes):

- ✅ Everything in Standard mode
- ✅ Code quality validation (docs/PATTERNS.md compliance)
- ✅ Documentation completeness check
- ✅ Deprecated option detection
- ✅ Anti-pattern detection

### Specific Checks

**Syntax Check**:

- Nix expression syntax validation
- Flake lock file consistency
- Import statement verification
- No evaluation, very fast

**Feature Validation**:

- Feature dependency resolution
- Circular dependency detection
- Missing feature warnings
- Feature conflict detection

**Security Validation**:

- Service hardening checks (DynamicUser, ProtectSystem)
- Secret management verification (no evaluation-time reads)
- Firewall configuration review
- SSH hardening verification
- Root service detection

**Quality Validation**:

- Module documentation completeness
- Option description quality
- Code style consistency (PATTERNS.md)
- Anti-pattern detection (NIXOS-ANTI-PATTERNS.md)

**Deprecation Check**:

- Deprecated NixOS options
- Outdated module patterns
- Legacy configuration detection
- Migration path suggestions

## Validation Workflow

### Development Workflow

```bash
# Quick iteration during development
/nix-validate
Quick validation

# Before committing
/nix-validate
Standard validation

# Before creating PR
/nix-validate
Full validation
```

### CI/CD Integration

```bash
# In CI pipeline
/nix-validate
CI mode
# Runs: Syntax + Feature + Security (no quality checks)
```

## Implementation Details

### Quick Mode (Default for "Quick validation")

```bash
# Called helpers:
just _validate-syntax              # Syntax check (5s)
nix eval .#lib.validateFeatures    # Feature validation (10s)
# Total: ~15-30s
```

### Standard Mode (Default)

```bash
# Called helpers:
just _validate-syntax              # Syntax check (5s)
nix eval .#lib.validateFeatures    # Feature validation (10s)
nix eval .#lib.validateSecurity    # Security validation (15s)
just _check-module-structure       # Module structure (10s)
# Total: ~40-60s
```

### Full Mode

```bash
# Called helpers:
just _validate-syntax              # Syntax check (5s)
nix eval .#lib.validateFeatures    # Feature validation (10s)
nix eval .#lib.validateSecurity    # Security validation (15s)
just _validate-quality             # Quality validation (30s)
just _check-deprecated             # Deprecation check (20s)
just _check-anti-patterns          # Anti-pattern detection (30s)
# Total: ~90-120s
```

### Specific Checks

```bash
# Syntax only
nix flake check --no-build

# Security only
nix eval .#lib.validateSecurity --json | jq

# Deprecation only
just _check-deprecated
```

## Error Messages

### Common Errors

**Syntax Error**:

**Feature Dependency Error**:

```
❌ Feature Dependency Error
   Feature 'monitoring.grafana' requires 'monitoring.prometheus'

Fix: Enable monitoring.prometheus in host configuration:
   features.monitoring.prometheus.enable = true;
```

**Security Error**:

```
❌ Security Error: Service running as root
   Service: myservice
   Location: modules/services/myservice.nix:23

Fix: Add systemd hardening:
   systemd.services.myservice.serviceConfig = {
     DynamicUser = true;
     ProtectSystem = "strict";
   };

Or run: /nix-fix
```

## Integration with Other Commands

### Before Deployment

```bash
# Validate before deploying
/nix-validate

# If validation passes, deploy
/nix-deploy p620
```

### Before PR

```bash
# Full validation
/nix-validate
Full validation

# Code review
/review

# Create PR
git commit && gh pr create
```

### With Auto-Fix

```bash
# Validate and find issues
/nix-validate

# Auto-fix detected issues
/nix-fix

# Validate again
/nix-validate
```

## Performance Optimization

### Caching

- Syntax checks are cached (no rebuild needed)
- Feature validation uses lazy evaluation
- Security validation reuses evaluation results

### Parallel Execution

- Multiple hosts can be validated in parallel
- Independent checks run concurrently
- Results aggregated at the end

### Smart Defaults

- Quick mode for interactive development
- Standard mode for pre-commit
- Full mode for CI/CD and PRs

## Best Practices

### DO ✅

- Run quick validation frequently during development
- Run standard validation before committing
- Run full validation before creating PRs
- Fix errors immediately (don't accumulate technical debt)
- Use specific checks for targeted debugging

### DON'T ❌

- Skip validation before deployment (recipe for disaster)
- Ignore warnings (they become errors later)
- Run full validation on every file save (too slow)
- Commit code that fails validation
- Disable validation in CI/CD (defeats the purpose)

## Troubleshooting

### Validation Hangs

```bash
# Check if evaluation is stuck
ps aux | grep nix-instantiate

# Kill stuck process
pkill nix-instantiate

# Run with timeout
timeout 300 /nix-validate
```

### False Positives

```bash
# Skip specific validation
/nix-validate
Quick validation

# Create issue: /new_task "False positive in validation"
```

### Validation Too Slow

```bash
# Use quick mode for development
/nix-validate
Quick validation

# Run full validation only before PR
/nix-validate
Full validation
```

## Related Commands

- `/nix-test` - Test configurations build successfully
- `/nix-fix` - Auto-fix detected issues
- `/nix-security` - Comprehensive security audit
- `/review` - Code review with anti-pattern detection
- `/nix-deploy` - Deploy validated configuration

---

**Pro Tip**: Set up a git pre-commit hook to run quick validation automatically:

```bash
/nix-precommit
Install validation hook
```

This ensures you never commit invalid configuration! 🚀
