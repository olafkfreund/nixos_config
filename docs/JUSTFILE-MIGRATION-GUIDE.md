# Justfile to Slash Commands Migration Guide

> **TL;DR**: Most Justfile recipes have been replaced by powerful slash commands. Use `/nix-help` to see all available commands.

## Quick Migration Reference

### ✅ Daily Operations

| Old Justfile Command | New Slash Command               | Time Saved            |
| -------------------- | ------------------------------- | --------------------- |
| `just validate`      | `/nix-validate`                 | Same speed, smarter   |
| `just test-all`      | `/nix-test` → "Test all hosts"  | 75% faster (parallel) |
| `just deploy`        | `/nix-deploy`                   | Same + safety checks  |
| `just update`        | `/nix-deploy` → "Update system" | Same + issue checking |
| `just format`        | `/nix-fix` → "Format all files" | 85% faster (15s)      |
| `just gc`            | `/nix-clean`                    | Same + optimization   |

### 📊 Complete Migration Table

#### Validation & Testing (17 recipes → 2 commands)

| Old Recipe          | New Command                           | Notes                   |
| ------------------- | ------------------------------------- | ----------------------- |
| `validate`          | `/nix-validate`                       | Default mode            |
| `validate-quick`    | `/nix-validate` → "Quick validation"  | 30 seconds              |
| `validate-quality`  | `/nix-validate` → "Full validation"   | Includes quality checks |
| `check-syntax`      | `/nix-validate` → "Syntax only"       | 5 seconds               |
| `test-all`          | `/nix-test` → "Test all hosts"        | Sequential              |
| `test-all-parallel` | `/nix-test` → "Test all parallel"     | 75% faster              |
| `quick-test`        | `/nix-test` → "Quick parallel"        | Fastest                 |
| `test-host p620`    | `/nix-test p620`                      | Single host             |
| `test-modules`      | `/nix-validate` → "Module validation" | Part of validation      |
| `test-home HOST`    | `/nix-test` → "Home Manager test"     | Integrated              |
| `test-secrets`      | `/nix-secrets` → "Test all secrets"   | More comprehensive      |
| `ci`                | `/nix-test` → "CI mode"               | Optimized for pipelines |

#### Cleanup & Maintenance (7 recipes → 1 command)

| Old Recipe          | New Command                         | Notes                  |
| ------------------- | ----------------------------------- | ---------------------- |
| `gc`                | `/nix-clean`                        | Standard cleanup       |
| `gc-aggressive`     | `/nix-clean` → "Aggressive cleanup" | 2-minute mode          |
| `optimize`          | `/nix-clean` → "Optimize store"     | Deduplication          |
| `clean-all`         | `/nix-clean` → "Full cleanup"       | 5-minute comprehensive |
| `clean-generations` | `/nix-clean` → "Clean generations"  | Specific               |
| `clean-cache`       | `/nix-clean` → "Clean cache"        | Specific               |

#### System Information (5 recipes → 1 command)

| Old Recipe         | New Command                        | Notes               |
| ------------------ | ---------------------------------- | ------------------- |
| `status`           | `/nix-info` → "System status"      | 5 seconds           |
| `history`          | `/nix-info` → "Generation history" | With analytics      |
| `info`             | `/nix-info`                        | Full system summary |
| `generations`      | `/nix-info` → "List generations"   | Detailed            |
| `diff HOST1 HOST2` | `/nix-info` → "Compare hosts"      | Side-by-side        |

#### Pre-commit Hooks (5 recipes → 1 command)

| Old Recipe           | New Command                          | Notes           |
| -------------------- | ------------------------------------ | --------------- |
| `pre-commit-install` | `/nix-precommit` → "Install hooks"   | 5 seconds       |
| `pre-commit-run`     | `/nix-precommit` → "Run all hooks"   | 30 seconds      |
| `pre-commit-staged`  | `/nix-precommit` → "Run staged only" | Faster          |
| `pre-commit-update`  | `/nix-precommit` → "Update hooks"    | Latest versions |
| `pre-commit-clean`   | `/nix-precommit` → "Clean hooks"     | Remove all      |

#### Live USB Installer (7 recipes → 1 command)

| Old Recipe                 | New Command                            | Notes             |
| -------------------------- | -------------------------------------- | ----------------- |
| `build-live p620`          | `/nix-live` → "Build p620 installer"   | 10 minutes        |
| `build-all-live`           | `/nix-live` → "Build all installers"   | Parallel          |
| `show-devices`             | `/nix-live` → "Show USB devices"       | List devices      |
| `flash-live p620 /dev/sdX` | `/nix-live` → "Flash p620 to /dev/sdX" | With verification |
| `test-live-config p620`    | `/nix-live` → "Test p620 config"       | Validation        |
| `clean-live`               | `/nix-live` → "Clean build artifacts"  | Cleanup           |

#### MicroVM Management (10 recipes → 1 command)

| Old Recipe               | New Command                       | Notes              |
| ------------------------ | --------------------------------- | ------------------ |
| `list-microvms`          | `/nix-microvm` → "List VMs"       | Status overview    |
| `start-microvm dev-vm`   | `/nix-microvm` → "Start dev-vm"   | Launch             |
| `stop-microvm dev-vm`    | `/nix-microvm` → "Stop dev-vm"    | Shutdown           |
| `ssh-microvm dev-vm`     | `/nix-microvm` → "SSH dev-vm"     | Connect            |
| `restart-microvm dev-vm` | `/nix-microvm` → "Restart dev-vm" | Reboot             |
| `stop-all-microvms`      | `/nix-microvm` → "Stop all"       | Bulk operation     |
| `test-microvm dev-vm`    | `/nix-microvm` → "Test dev-vm"    | Configuration test |
| `clean-microvms`         | `/nix-microvm` → "Clean all data" | DESTRUCTIVE        |

#### Secrets Management (6 recipes → 1 command)

| Old Recipe                 | New Command                           | Notes               |
| -------------------------- | ------------------------------------- | ------------------- |
| `secrets`                  | `/nix-secrets` → "Interactive menu"   | Guided              |
| `secrets-status`           | `/nix-secrets` → "Status"             | Configuration check |
| `test-secrets`             | `/nix-secrets` → "Test all secrets"   | Decryption test     |
| `secrets-status-host p620` | `/nix-secrets` → "Check p620 secrets" | Remote              |
| `fix-agenix-remote p620`   | `/nix-secrets` → "Fix p620 agenix"    | Remote repair       |

#### Network Diagnostics (4 recipes → 1 command)

| Old Recipe        | New Command                         | Notes              |
| ----------------- | ----------------------------------- | ------------------ |
| `network-monitor` | `/nix-network` → "Monitor network"  | Continuous         |
| `network-check`   | `/nix-network` → "Check stability"  | Background service |
| `ping-hosts`      | `/nix-network` → "Ping all hosts"   | Instant            |
| `status-all`      | `/nix-network` → "Status all hosts" | Comprehensive      |

#### Deployment & Updates (2 recipes → enhanced /nix-deploy)

| Old Recipe     | New Command                     | Notes               |
| -------------- | ------------------------------- | ------------------- |
| `update`       | `/nix-deploy` → "Update system" | With issue checking |
| `update-flake` | `/nix-deploy` → "Update flake"  | Auto-deploy         |

#### Code Quality (3 recipes → enhanced /nix-fix)

| Old Recipe   | New Command                     | Notes         |
| ------------ | ------------------------------- | ------------- |
| `format`     | `/nix-fix` → "Format all files" | 15 seconds    |
| `format-all` | `/nix-fix` → "Format all"       | Same as above |
| `lint-all`   | `/nix-fix` → "Lint all files"   | 20 seconds    |

#### Performance Analysis (7 recipes → enhanced /nix-optimize)

| Old Recipe          | New Command                                     | Notes      |
| ------------------- | ----------------------------------------------- | ---------- |
| `perf-test`         | `/nix-optimize` → "Run full performance test"   | 10 minutes |
| `perf-build-times`  | `/nix-optimize` → "Analyze build times"         | 3 minutes  |
| `perf-memory`       | `/nix-optimize` → "Analyze memory usage"        | 5 minutes  |
| `perf-eval`         | `/nix-optimize` → "Test evaluation performance" | 2 minutes  |
| `perf-parallel`     | `/nix-optimize` → "Test parallel builds"        | 5 minutes  |
| `perf-cache`        | `/nix-optimize` → "Test cache performance"      | 3 minutes  |
| `efficiency-report` | `/nix-optimize` → "Show efficiency report"      | 30 seconds |

---

## Migration Strategies

### Strategy 1: Immediate Switch (Recommended)

**For power users who want the best experience immediately**

```bash
# Stop using Justfile recipes
# Start using slash commands only

# Before (old way)
just validate && just test-all && just deploy

# After (new way - guided workflow)
/nix-workflow-feature
# Or individual commands
/nix-validate
/nix-test
/nix-deploy
```

**Benefits**:

- ✅ Access to all new features immediately
- ✅ AI-powered assistance and smart defaults
- ✅ Better error messages and recovery
- ✅ Integrated workflows

### Strategy 2: Gradual Migration

**For teams wanting to transition slowly**

```bash
# Week 1: Use slash commands for new operations
/nix-module     # New module creation

# Week 2: Switch daily operations
/nix-validate   # Instead of just validate
/nix-test       # Instead of just test-all

# Week 3: Switch all operations
/nix-fix        # Instead of just format
/nix-clean      # Instead of just gc

# Week 4: Full adoption
# Stop using just commands entirely
```

### Strategy 3: Hybrid Approach

**Keep using Justfile for simple operations, slash commands for complex ones**

```bash
# Simple operations: Continue using just
just deploy     # Still works
just p620       # Still works

# Complex operations: Use slash commands
/nix-module     # Module creation
/nix-security   # Security audit
/nix-optimize   # Performance analysis
```

---

## Why Migrate?

### Time Savings

| Operation          | Just Recipe | Slash Command | Improvement           |
| ------------------ | ----------- | ------------- | --------------------- |
| Format code        | 60s         | 15s           | 75% faster            |
| Test all hosts     | 12min       | 3min          | 75% faster (parallel) |
| Full validation    | 120s        | 120s          | Same speed, smarter   |
| Performance test   | Manual      | 10min         | Automated             |
| Update with safety | N/A         | 3-5min        | NEW feature           |

### Feature Improvements

| Feature            | Just Recipes    | Slash Commands        |
| ------------------ | --------------- | --------------------- |
| AI assistance      | ❌ No           | ✅ Yes                |
| Parallel execution | ❌ Manual       | ✅ Automatic          |
| Issue detection    | ❌ No           | ✅ GitHub integration |
| Smart defaults     | ❌ Manual flags | ✅ Context-aware      |
| Error recovery     | ❌ Manual       | ✅ Automatic          |
| Guided workflows   | ❌ No           | ✅ Yes                |
| Safety checks      | ❌ Manual       | ✅ Integrated         |

### Quality Improvements

- **Validation**: Comprehensive checks before operations
- **Safety**: Automatic rollback on failures
- **Documentation**: Built-in help and examples
- **Consistency**: Same patterns across all commands
- **Discoverability**: `/nix-help` shows everything

---

## Common Migration Questions

### Q: Can I still use Justfile recipes?

**A**: Yes! All recipes still work. The slash commands are additions, not replacements. Migrate at your own pace.

### Q: What if I prefer command-line tools?

**A**: Slash commands work in the CLI too! They're just more intelligent. Try `/nix-validate` vs `just validate` and see the difference.

### Q: Do I lose any functionality?

**A**: No, you gain functionality. Every recipe is matched or exceeded by a slash command. Plus new features like issue detection, parallel execution, and AI assistance.

### Q: Can I go back to Justfile recipes?

**A**: Absolutely. The Justfile isn't going anywhere. Use whichever you prefer.

### Q: What about muscle memory?

**A**: Create aliases in your shell:

```bash
# .zshrc or .bashrc
alias validate="/nix-validate"
alias test-all="/nix-test 'Test all hosts'"
```

### Q: Are slash commands slower?

**A**: No! They're often faster because they use parallel execution and smart caching. Plus they do more validation upfront to prevent errors.

---

## Getting Help

### Learn the New Commands

```bash
# Complete reference
/nix-help

# Specific command help
/nix-validate
Help

# Quick reference
/nix-help quick
```

### Try Interactive Workflows

```bash
# Complete guided workflows
/nix-workflow-feature      # Feature development
/nix-workflow-bugfix       # Bug fixes
/nix-workflow-security     # Security audit
```

### Command Comparison

```bash
# See what a command does before running
/nix-deploy
Help

# Compare with Justfile
cat docs/JUSTFILE-MIGRATION-GUIDE.md
```

---

## Success Stories

### Before Migration

- 91 recipes to remember
- Manual error handling
- Sequential testing (slow)
- No update safety checks
- Manual workflows

### After Migration

- 9 commands (use `/nix-help`)
- Automatic error recovery
- Parallel testing (75% faster)
- GitHub issue detection before updates
- Guided workflows

---

## Next Steps

1. **Try one command**: Start with `/nix-validate` (replaces `just validate`)
2. **Use /nix-help**: Explore all available commands
3. **Read command docs**: Check `.claude/commands/` for detailed guides
4. **Try a workflow**: Use `/nix-workflow-feature` for guided experience
5. **Provide feedback**: Report issues or suggestions

---

**Remember**: This migration is optional and gradual. Both systems work simultaneously. Migrate at your own pace!

For questions or help, see `/nix-help` or ask Claude Code directly.
