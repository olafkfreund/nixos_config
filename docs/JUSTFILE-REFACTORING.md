# Justfile Refactoring Plan

> Goal: Reduce Justfile from 1,415 lines (91 recipes) to ~300 lines (20-25 core recipes)
> Strategy: Replace user-facing commands with Claude Code slash commands

## Current State Analysis

**Justfile Size**: 1,415 lines
**Recipe Count**: 91 recipes
**Problem**: Bloated, duplicated functionality, hard to maintain

## Categorization & Refactoring Plan

### ✅ Category 1: Validation & Testing (25 recipes → 3 commands)

**Current Recipes:**

```
validate, validate-quick, validate-quality, validate-full
check, check-syntax, check-updates, check-deprecated
test-all, test-all-parallel, test-build-all, test-build-all-parallel
test-home, test-secrets, test-all-secrets, test-packages
test-modules, test-home-modules, test-nixpkgs-stable, test-all-users
quick-test, ci, ci-quick, security-scan, test-rollback
```

**Refactor To:**

**New Command**: `/nix-validate` - Comprehensive validation

- Replaces: validate, validate-quick, validate-quality, validate-full, check, check-syntax
- Features: Syntax check, quality validation, security scan, full validation
- Modes: quick, standard, full
- Time: 5s (quick) to 2min (full)

**New Command**: `/nix-test` - Testing suite

- Replaces: test-all, test-all-parallel, test-build-all, test-home, test-modules, ci
- Features: Build testing, home manager testing, module testing, parallel execution
- Modes: single-host, all-hosts, parallel, ci
- Time: 30s (single) to 3min (all parallel)

**Keep in Justfile** (Low-level helpers):

```just
# Called by slash commands, not by users directly
_test-host HOST:          # Helper for testing single host
_test-parallel:           # Helper for parallel testing
_check-syntax-internal:   # Internal syntax checker
```

### ✅ Category 2: Deployment (11 recipes → 1 command + helpers)

**Current Recipes:**

```
deploy, update, update-flake
razer, p620, p510, dex5550, samsung, samsung-debug
deploy-all, deploy-all-parallel, deploy-interactive
```

**Refactor To:**

**Existing Command**: `/nix-deploy` (already exists!)

- Already handles: Single host, all hosts, parallel, emergency
- **Just needs**: Integration with preview-updates, update-workflow

**Keep in Justfile** (Low-level helpers):

```just
# Called by /nix-deploy, not by users
_deploy-host HOST:        # Helper for single host deployment
_deploy-parallel:         # Helper for parallel deployment
_preview-updates HOST:    # Helper for update preview
```

**Remove**:

- Individual host recipes (p620, razer, etc.) → Use `/nix-deploy` instead
- deploy-interactive → Built into `/nix-deploy`

### ✅ Category 3: Pre-commit (6 recipes → 1 command)

**Current Recipes:**

```
pre-commit-install, pre-commit-run, pre-commit-staged
pre-commit-update, pre-commit-clean, pre-commit-hook
```

**Refactor To:**

**New Command**: `/nix-precommit` - Pre-commit management

- Replaces: All 6 pre-commit recipes
- Features: Install, run, update, clean, run specific hook
- Modes: install, run, staged, update, clean, hook <name>
- Time: 5s (install) to 30s (run all)

**Keep in Justfile** (Low-level helpers):

```just
_precommit-install:       # Helper
_precommit-run-all:       # Helper
```

### ✅ Category 4: Formatting & Linting (3 recipes → Enhanced /nix-fix)

**Current Recipes:**

```
format-all, lint-all, format
```

**Refactor To:**

**Enhance Existing**: `/nix-fix`

- Add modes: format-only, lint-only, fix-all
- Features: Format (nixpkgs-fmt, shfmt, prettier), Lint (statix, deadnix, shellcheck)
- Already handles: Anti-pattern fixes, security hardening

**Remove**:

- format-all, lint-all, format → All covered by `/nix-fix`

### ✅ Category 5: Performance Analysis (7 recipes → Enhanced /nix-optimize)

**Current Recipes:**

```
perf-test, perf-build-times, perf-memory, perf-eval
perf-parallel, perf-cache, efficiency-report
```

**Refactor To:**

**Enhance Existing**: `/nix-optimize`

- Add analyses: build-times, memory, evaluation, cache efficiency
- Features: Comprehensive performance report, specific optimization suggestions
- Already has: Build performance, disk usage, memory tuning, boot performance

**Remove**:

- All perf-\* recipes → Integrated into `/nix-optimize`

### ✅ Category 6: Cleanup & Maintenance (6 recipes → 1 command)

**Current Recipes:**

```
gc, gc-aggressive, optimize, full-cleanup, clean-all, cleanup-dead-code
```

**Refactor To:**

**New Command**: `/nix-clean` - Cleanup operations

- Replaces: All cleanup recipes
- Features: Garbage collection, store optimization, dead code removal
- Modes: gc (standard), gc-aggressive, optimize, full, dead-code
- Time: 30s (gc) to 5min (full)

**Keep in Justfile** (Low-level helpers):

```just
_gc-standard:            # Helper
_gc-aggressive:          # Helper
_optimize-store:         # Helper
```

### ✅ Category 7: Information & Status (8 recipes → 1 command)

**Current Recipes:**

```
status, history, info, metadata, docs
help-extended, summary, analyze-config
```

**Refactor To:**

**New Command**: `/nix-info` - System information

- Replaces: All info/status recipes
- Features: System status, history, metadata, configuration analysis
- Modes: status, history, metadata, summary, config-analysis
- Time: 5s (status) to 30s (full analysis)

**Keep in Justfile** (Low-level helpers):

```just
_system-status:          # Helper
_config-analysis:        # Helper
```

### ✅ Category 8: Live USB (5 recipes → 1 command)

**Current Recipes:**

```
build-all-live, show-devices, clean-live, live-help
```

**Refactor To:**

**New Command**: `/nix-live` - Live USB management

- Replaces: All live USB recipes
- Features: Build images, show devices, flash, clean, help
- Modes: build <host>, show-devices, flash <host> <device>, clean, help
- Time: 30s (show) to 10min (build)

**Keep in Justfile** (Low-level helpers):

```just
_build-live-iso HOST:    # Helper for building ISOs
_flash-device:           # Helper for flashing
```

### ✅ Category 9: MicroVM (5 recipes → 1 command)

**Current Recipes:**

```
list-microvms, stop-all-microvms, clean-microvms
test-all-microvms, microvm-help
```

**Refactor To:**

**New Command**: `/nix-microvm` - MicroVM management

- Replaces: All MicroVM recipes
- Features: List, start, stop, clean, test, help
- Modes: list, start <vm>, stop <vm>, stop-all, clean, test, help
- Time: Instant (list) to 2min (test-all)

**Keep in Justfile** (Low-level helpers):

```just
_list-microvms:          # Helper
_stop-microvm VM:        # Helper
```

### ✅ Category 10: Secrets Management (3 recipes → 1 command)

**Current Recipes:**

```
secrets, secrets-status, test-all-secrets
```

**Refactor To:**

**New Command**: `/nix-secrets` - Secret management

- Replaces: secrets, secrets-status, test-all-secrets
- Features: Manage secrets, check status, test access, create, edit
- Modes: status, test, create <name>, edit <name>, rekey
- Time: 5s (status) to 30s (rekey-all)

**Keep in Justfile** (Low-level helpers):

```just
_secrets-status:         # Helper
_test-secret NAME:       # Helper
```

### ✅ Category 11: Network (4 recipes → 1 command)

**Current Recipes:**

```
network-monitor, network-check, ping-hosts, status-all
```

**Refactor To:**

**New Command**: `/nix-network` - Network operations

- Replaces: All network recipes
- Features: Monitor, check connectivity, ping hosts, status
- Modes: monitor, check, ping, status
- Time: Instant (check) to continuous (monitor)

**Keep in Justfile** (Low-level helpers):

```just
_ping-host HOST:         # Helper
_network-status:         # Helper
```

### ✅ Category 12: Keep in Justfile (Core Operations)

**Essential Recipes to Keep:**

```just
default:                 # Show available commands
deploy:                  # Quick deploy (calls nh)
update:                  # Quick update (calls nh)
repl:                    # Nix REPL
dev-shell:               # Development shell
watch:                   # Watch for changes
backup:                  # Backup configuration

# Low-level helpers (called by commands)
_test-host HOST:         # Test single host
_deploy-host HOST:       # Deploy single host
_validate-syntax:        # Syntax validation
# ... (other helpers)
```

**Keep Because:**

- Used frequently by developers
- Don't benefit from AI assistance
- Called by other tools/scripts
- Need shell performance

## Summary of Changes

### Before Refactoring

- **1,415 lines**
- **91 recipes**
- **User calls**: `just validate`, `just test-all-parallel`, `just p620`, etc.

### After Refactoring

- **~300 lines** (79% reduction)
- **~25 core recipes** (73% reduction)
- **User calls**: `/nix-validate`, `/nix-test`, `/nix-deploy p620`, etc.

### New Slash Commands to Create

1. `/nix-validate` - Validation suite
2. `/nix-test` - Testing suite
3. `/nix-precommit` - Pre-commit management
4. `/nix-clean` - Cleanup operations
5. `/nix-info` - System information
6. `/nix-live` - Live USB management
7. `/nix-microvm` - MicroVM management
8. `/nix-secrets` - Secret management
9. `/nix-network` - Network operations

### Enhanced Existing Commands

1. `/nix-deploy` - Add preview-updates, update-workflow
2. `/nix-fix` - Add format-only, lint-only modes
3. `/nix-optimize` - Add detailed performance breakdowns

### Justfile Simplified To

**User-Facing (7 recipes)**:

```just
default        # List commands
deploy         # Quick deploy
update         # Quick update
repl           # Nix REPL
dev-shell      # Dev environment
watch          # Watch changes
backup         # Backup config
```

**Helpers (~18 recipes)**:

```just
# Validation helpers
_validate-syntax
_check-quality
_test-host HOST

# Deployment helpers
_deploy-host HOST
_preview-updates HOST

# Testing helpers
_test-parallel
_test-single HOST

# Cleanup helpers
_gc-standard
_optimize-store

# ... (other helpers)
```

## Migration Strategy

### Phase 1: Create New Commands (Week 1)

1. Create `/nix-validate`
2. Create `/nix-test`
3. Create `/nix-clean`
4. Create `/nix-info`

### Phase 2: Create Specialized Commands (Week 2)

5. Create `/nix-precommit`
6. Create `/nix-live`
7. Create `/nix-microvm`
8. Create `/nix-secrets`
9. Create `/nix-network`

### Phase 3: Enhance Existing Commands (Week 2)

10. Enhance `/nix-deploy`
11. Enhance `/nix-fix`
12. Enhance `/nix-optimize`

### Phase 4: Simplify Justfile (Week 3)

13. Remove old recipes
14. Keep only helpers
15. Update documentation
16. Test migration

### Phase 5: Update Documentation (Week 3)

17. Update CLAUDE.md references
18. Update /nix-help
19. Update README
20. Create migration guide for users

## Benefits

### For Users

- ✅ **Simpler**: 9 commands instead of 91 recipes
- ✅ **Smarter**: AI-assisted operations with context
- ✅ **Faster**: Guided workflows, auto-optimization
- ✅ **Discoverable**: `/nix-help` shows all commands
- ✅ **Consistent**: All commands follow same patterns

### For Maintainers

- ✅ **79% less code** in Justfile (1,415 → 300 lines)
- ✅ **Single source of truth** (commands, not recipes)
- ✅ **Easier updates** (update command, not recipe)
- ✅ **Better organization** (categorized by function)
- ✅ **Less duplication** (helpers shared by commands)

### Technical Benefits

- ✅ **AI assistance**: Commands get context, make smart decisions
- ✅ **Error handling**: Better error messages and recovery
- ✅ **Validation**: Automatic validation before operations
- ✅ **Documentation**: Built-in help and examples
- ✅ **Extensibility**: Easy to add new features

## Command Design Examples

### `/nix-validate` Design

```markdown
# NixOS Validation Suite

Comprehensive validation with multiple modes.

## Usage

Quick validation (30s):
/nix-validate
Quick validation

Standard validation (1min):
/nix-validate

Full validation with quality checks (2min):
/nix-validate
Full validation

## Features

- Syntax validation (nix flake check)
- Feature validation (lib.validateFeatures)
- Security validation (lib.validateSecurity)
- Quality validation (docs, patterns)
- Deprecation checking

## Modes

- quick: Syntax + feature validation only
- standard: + security validation
- full: + quality validation + deprecation

## Helpers Called

- just \_validate-syntax
- just \_check-quality (full mode)
```

### `/nix-test` Design

```markdown
# NixOS Testing Suite

Test configurations locally before deployment.

## Usage

Test single host:
/nix-test p620

Test all hosts in parallel:
/nix-test
Test all hosts

CI mode (quick validation):
/nix-test
CI mode

## Features

- Build testing (nixosConfigurations)
- Home Manager testing
- Module testing
- Secret access testing
- Parallel execution
- CI integration

## Modes

- single: Test specific host
- all: Test all hosts sequentially
- parallel: Test all hosts in parallel (fastest)
- ci: Quick validation for CI/CD

## Helpers Called

- just \_test-host HOST
- just \_test-parallel (parallel mode)
```

## Implementation Priority

### High Priority (Create First)

1. `/nix-validate` - Used daily
2. `/nix-test` - Used daily
3. `/nix-clean` - Used weekly
4. Enhance `/nix-deploy` - Used multiple times daily

### Medium Priority

5. `/nix-info` - Used for debugging
6. `/nix-precommit` - Used in development
7. Enhance `/nix-fix` - Used before commits

### Low Priority (Nice to Have)

8. `/nix-live` - Used occasionally
9. `/nix-microvm` - Used for development
10. `/nix-secrets` - Used for setup
11. `/nix-network` - Used for debugging

## Success Metrics

- [ ] Justfile reduced from 1,415 to ~300 lines (79% reduction)
- [ ] Recipe count reduced from 91 to ~25 (73% reduction)
- [ ] All user-facing operations available as commands
- [ ] Documentation updated to reference commands
- [ ] Migration guide created
- [ ] User adoption > 80% within 2 weeks
- [ ] Zero regression in functionality
- [ ] Improved user satisfaction

## Rollback Plan

If migration fails:

1. Keep old Justfile as `Justfile.backup`
2. Commands can call old recipes as fallback
3. Gradual migration (both systems work simultaneously)
4. Full rollback possible with `mv Justfile.backup Justfile`

---

**Next Steps**: Begin Phase 1 - Create core commands (/nix-validate, /nix-test, /nix-clean, /nix-info)
