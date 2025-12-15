# Replaced Justfile Recipes

This document tracks all Justfile recipes replaced by Claude Code commands during the refactoring project.

**Total Replaced**: 79 of 91 recipes (87%)
**Remaining**: 12 recipes (helpers + essential operations)

---

## Phase 1: Core Commands (39 recipes → 4 commands)

### Replaced by `/nix-validate` (14 recipes)

- `validate` - Full configuration validation
- `validate-quick` - Quick syntax + feature validation
- `validate-quality` - Quality and pattern validation
- `check-syntax` - Nix syntax checking
- `check-module MODULE` - Module-specific syntax check
- `test-modules` - Module structure validation
- `lint` - Code linting
- `check-deps` - Dependency validation
- `check-features` - Feature flag validation
- `check-deprecations` - Deprecation checking
- `analyze-config` - Configuration analysis
- `validate-secrets` - Secret configuration validation
- `validate-features` - Feature dependency validation
- `validate-security` - Security configuration validation

### Replaced by `/nix-test` (13 recipes)

- `test-all` - Test all hosts sequentially
- `test-all-parallel` - Test all hosts in parallel
- `quick-test` - Quick parallel testing
- `test-host HOST` - Test specific host
- `test-home HOST` - Home Manager testing
- `test-secrets` - Secret decryption testing
- `test-all-secrets` - All hosts secret testing
- `ci` - CI/CD pipeline
- `ci-quick` - Quick CI validation
- `bench-host HOST` - Build benchmarking
- `test-migration HOST` - Migration testing
- `test-rollback HOST` - Rollback testing
- `test-parallel-builds` - Parallel build testing

### Replaced by `/nix-clean` (7 recipes)

- `gc` - Standard garbage collection
- `gc-aggressive` - Aggressive cleanup
- `optimize` - Store optimization
- `clean-all` - Full system cleanup
- `clean-build` - Build artifacts cleanup
- `clean-generations` - Old generations cleanup
- `clean-cache` - Cache cleanup

### Replaced by `/nix-info` (5 recipes)

- `status` - System status overview
- `history` - Generation history
- `info` - System information
- `generations` - List generations
- `diff HOST1 HOST2` - Compare host configurations
- `diff-hosts HOST1 HOST2` - Host configuration diff

---

## Phase 2: Specialized Commands (26 recipes → 5 commands)

### Replaced by `/nix-precommit` (5 recipes)

- `pre-commit-install` - Install pre-commit hooks
- `pre-commit-run` - Run all hooks
- `pre-commit-staged` - Run on staged files
- `pre-commit-update` - Update hook versions
- `pre-commit-clean` - Clean hook installations

### Replaced by `/nix-live` (7 recipes)

- `build-live HOST` - Build live USB for host
- `build-all-live` - Build all live USBs
- `show-devices` - Show USB devices
- `flash-live HOST DEVICE` - Flash ISO to USB
- `test-live-config HOST` - Test live configuration
- `test-hw-config HOST` - Test hardware config
- `clean-live` - Clean live build artifacts
- `live-help` - Live installer help

### Replaced by `/nix-microvm` (9 recipes)

- `list-microvms` - List all VMs
- `start-microvm VM` - Start specific VM
- `stop-microvm VM` - Stop specific VM
- `ssh-microvm VM` - SSH into VM
- `stop-all-microvms` - Stop all VMs
- `restart-microvm VM` - Restart VM
- `rebuild-microvm VM` - Rebuild VM
- `test-microvm VM` - Test VM configuration
- `test-all-microvms` - Test all VMs
- `clean-microvms` - Clean VM data
- `microvm-help` - MicroVM help

### Replaced by `/nix-secrets` (6 recipes)

- `secrets` - Interactive secrets management
- `secrets-status` - Check secrets status
- `test-secrets` - Test secret decryption (duplicate from Phase 1)
- `test-all-secrets` - Test all secrets (duplicate from Phase 1)
- `secrets-status-host HOST` - Host-specific secrets
- `fix-agenix-remote HOST` - Remote agenix fixes

### Replaced by `/nix-network` (4 recipes)

- `network-monitor` - Continuous network monitoring
- `network-check` - Network stability check
- `ping-hosts` - Ping all infrastructure hosts
- `status-all` - All hosts network status

---

## Phase 3: Enhanced Commands (12 recipes → 3 enhanced commands)

### Enhanced `/nix-deploy` (2 recipes)

- `update` - Update system packages
- `update-flake` - Update flake inputs

### Enhanced `/nix-fix` (3 recipes)

- `format` - Format Nix files
- `format-all` - Format all files
- `lint-all` - Lint all files

### Enhanced `/nix-optimize` (7 recipes)

- `perf-test` - Full performance testing
- `perf-build-times` - Build time measurement
- `perf-memory` - Memory usage analysis
- `perf-eval` - Evaluation performance
- `perf-parallel` - Parallel build efficiency
- `perf-cache` - Cache performance
- `efficiency-report` - Configuration efficiency metrics

---

## Recipes to KEEP (12 essential recipes)

### Deployment Recipes (6)

- `deploy` - Local deployment
- `p620` - Deploy to P620
- `p510` - Deploy to P510
- `razer` - Deploy to Razer
- `samsung` - Deploy to Samsung
- `quick-deploy HOST` - Smart deployment with change detection

### Development Recipes (6)

- `dev-shell` - Enter development shell
- `repl` - Open Nix REPL
- `repl-nixpkgs` - REPL with nixpkgs
- `show-drv PACKAGE` - Show package derivation
- `show-build HOST` - Show what would be built
- `update-input INPUT` - Update specific flake input

### Helper Recipes (all `_*` prefixed)

- All underscore-prefixed helper recipes used internally by commands
- These provide reusable functionality for both commands and recipes

---

## Migration Strategy

### Step 1: Create Backup

```bash
cp Justfile Justfile.backup-$(date +%Y%m%d)
```

### Step 2: Remove Replaced Recipes

Remove all 79 recipes listed above while preserving:

- Essential deployment recipes (6)
- Development/debugging recipes (6)
- Helper recipes (all `_*` prefixed)

### Step 3: Add Migration Comments

Add comment blocks indicating which command replaces each section:

```just
# =============================================================================
# VALIDATION AND TESTING
# =============================================================================
# NOTE: Most validation recipes have been replaced by slash commands:
#   - Use /nix-validate for all validation operations
#   - Use /nix-test for build testing
# See: .claude/commands/nix-validate.md and nix-test.md

# ... keep only essential recipes ...
```

### Step 4: Update Recipe Count

Expected final Justfile:

- **Lines**: ~300-400 (from 1,415) - 70% reduction
- **Recipes**: ~25-30 (from 91) - 67% reduction
- **Helpers**: Keep all (reused by commands)

---

## Verification Checklist

After migration:

- [ ] All 79 replaced recipes removed
- [ ] 12 essential recipes remain functional
- [ ] All helper recipes (`_*`) preserved
- [ ] Migration comments added to each section
- [ ] Backup created before changes
- [ ] Test essential recipes work correctly
- [ ] Documentation updated to reference commands
- [ ] Users can find new command equivalents easily

---

**Next Action**: Create cleaned Justfile with replaced recipes removed
