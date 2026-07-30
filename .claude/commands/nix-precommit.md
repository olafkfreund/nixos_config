# NixOS Pre-commit Hook Management

Manage pre-commit hooks for automated code quality checks before every commit.

**Replaces Justfile recipes**: `pre-commit-install`, `pre-commit-run`, `pre-commit-staged`, `pre-commit-update`, `pre-commit-clean`, `pre-commit-hook`

## Quick Usage

**Install hooks**:

```
/nix-precommit
Install hooks
```

**Run all hooks**:

```
/nix-precommit
Run all hooks
```

**Run on staged files only**:

```
/nix-precommit
Run staged
```

**Update hooks**:

```
/nix-precommit
Update hooks
```

## Features

### Hook Management

**Install** (~5 seconds):

- ✅ Installs pre-commit hooks in `.git/hooks/`
- ✅ Automatically runs before every commit
- ✅ Prevents commits with errors
- ✅ One-time setup per repository

**Run All** (~30 seconds):

- ✅ Runs all configured hooks on all files
- ✅ Formatting (nixpkgs-fmt, shfmt, prettier)
- ✅ Linting (statix, deadnix, shellcheck, markdownlint)
- ✅ Validation (check syntax, security)
- ✅ Useful for CI/CD pipelines

**Run Staged** (~10 seconds):

- ✅ Runs hooks only on staged files (fast)
- ✅ Automatic before each commit
- ✅ Only checks what you're committing
- ✅ Fastest feedback for developers

**Update** (~15 seconds):

- ✅ Updates hook versions to latest
- ✅ Updates pre-commit framework
- ✅ Fetches new hook definitions
- ✅ Run monthly for latest improvements

**Clean** (~2 seconds):

- ✅ Clears pre-commit cache
- ✅ Fixes hook installation issues
- ✅ Removes stale data
- ✅ Run if hooks behave strangely

### Specific Hook Execution

**Run specific hook**:

```
/nix-precommit
Run hook nixpkgs-fmt
```

**Available hooks**:

- `nixpkgs-fmt` - Format Nix files
- `statix` - Lint Nix files (anti-pattern detection)
- `deadnix` - Find dead Nix code
- `shfmt` - Format shell scripts
- `shellcheck` - Lint shell scripts
- `prettier` - Format markdown, YAML, JSON
- `markdownlint` - Lint markdown files

## Pre-commit Workflow

### Initial Setup

```bash
# One-time installation
/nix-precommit
Install hooks

# Hooks now run automatically on every commit!
```

### Daily Development

```bash
# Hooks run automatically when you commit
git add .
git commit -m "feat: add new feature"

# Manual run before commit (optional)
/nix-precommit
Run staged
```

### Fixing Hook Failures

```bash

# 2. Auto-fix if possible
/nix-fix

# 3. Run hooks again
/nix-precommit
Run staged

# 4. Commit again
git commit -m "feat: add new feature"
```

### Bypassing Hooks (Emergency Only)

```bash
# Skip hooks (NOT RECOMMENDED)
git commit --no-verify -m "emergency fix"

# - Time-sensitive deployment
```

## Output Format

### Install Success

```
🔨 Installing Pre-commit Hooks

📦 Setting up pre-commit environment...
   ✅ Framework installed

🔗 Installing hooks...
   ✅ nixpkgs-fmt
   ✅ statix
   ✅ deadnix
   ✅ shfmt
   ✅ shellcheck
   ✅ prettier
   ✅ markdownlint

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Pre-commit Hooks Installed
Total: 7 hooks active
Time: 5 seconds

Hooks will now run automatically before every commit!
To run manually: /nix-precommit
```

### Update Output

```
⬆️ Updating Pre-commit Hooks

📦 Updating pre-commit framework...
   ✅ pre-commit: 3.5.0 → 3.6.0

🔄 Updating hook versions...
   ✅ nixpkgs-fmt: Updated
   ✅ statix: 0.7.1 → 0.7.2
   ✅ deadnix: Updated
   ✅ shfmt: v3.7.0 → v3.8.0
   ✅ shellcheck: Updated
   ✅ prettier: 3.1.0 → 3.2.0
   ✅ markdownlint: Updated

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Hooks Updated
Updated: 7 hooks
Time: 12 seconds
```

## Implementation Details

### Install Command

```bash
# Install pre-commit framework
pre-commit install

# Install commit-msg hook (for conventional commits)
pre-commit install --hook-type commit-msg
```

### Run All Command

```bash
# Run all hooks on all files
pre-commit run --all-files
```

### Run Staged Command

```bash
# Run hooks on staged files only
pre-commit run
```

### Update Command

```bash
# Update hook versions
pre-commit autoupdate
```

### Clean Command

```bash
# Clear pre-commit cache
pre-commit clean
```

### Run Specific Hook

```bash
# Run one hook on all files
pre-commit run <hook-name> --all-files
```

## Hook Configuration

### Configured Hooks

**Nix Formatting & Linting**:

- `nixpkgs-fmt` - Official Nix formatter
- `statix` - Nix linter (anti-pattern detection)
- `deadnix` - Find unused Nix code

**Shell Scripting**:

- `shfmt` - Shell script formatter
- `shellcheck` - Shell script linter

**Documentation**:

- `prettier` - Format markdown, YAML, JSON
- `markdownlint` - Markdown linter

**Validation**:

- Custom hooks for NixOS-specific validation
- Check for evaluation-time secrets
- Verify DynamicUser usage

### Hook Configuration File

Located at: `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/nix-community/nixpkgs-fmt
    rev: v1.3.0
    hooks:
      - id: nixpkgs-fmt

  - repo: https://github.com/nix-community/statix
    rev: v0.7.2
    hooks:
      - id: statix

  # ... more hooks
```

## Integration with Development Workflow

### With Git Workflow

```bash
# Normal development
git add .
git commit -m "feat: add feature"

# Pre-commit fixed formatting
git add .  # Stage auto-fixes
git commit -m "feat: add feature"
```

### With /nix-fix

```bash
# If pre-commit finds issues
/nix-fix
# Auto-fixes many anti-patterns

/nix-precommit
Run staged
# Verify fixes

git add .
git commit -m "feat: add feature"
```

### With CI/CD

```bash
# In GitHub Actions / GitLab CI
/nix-precommit
Run all hooks
# Ensures code quality in CI
```

## Best Practices

### DO ✅

- Install hooks on every repository (`/nix-precommit Install`)
- Let hooks run automatically (don't bypass)
- Fix issues found by hooks (don't ignore)
- Update hooks monthly (`/nix-precommit Update`)
- Run all hooks before PR (`/nix-precommit Run all`)
- Use `/nix-fix` to auto-fix issues

### DON'T ❌

- Bypass hooks with `--no-verify` (except emergencies)
- Ignore hook failures (fix them!)
- Disable specific hooks (they're there for a reason)
- Forget to stage auto-fixes (hooks fix files)
- Skip hook installation (one-time setup)

## Troubleshooting

### Hooks Not Running

```bash
# Check if hooks installed
ls -la .git/hooks/pre-commit

# Reinstall hooks
/nix-precommit
Install hooks
```

### Hooks Failing Strangely

```bash
# Clean cache
/nix-precommit
Clean cache

# Reinstall
/nix-precommit
Install hooks
```

### Hook Too Slow

```bash
# Run only on staged files (faster)
/nix-precommit
Run staged

# Edit .pre-commit-config.yaml to disable specific hooks
```

### Can't Fix Hook Errors

```bash
# Try auto-fix first
/nix-fix

# Run hooks again
/nix-precommit
Run staged

# If still failing, review errors and fix manually
```

## Hook Timing

### By Hook Type

**Formatting** (fast):

- nixpkgs-fmt: ~3s
- shfmt: ~2s
- prettier: ~4s

**Linting** (medium):

- statix: ~5s
- deadnix: ~4s
- shellcheck: ~6s
- markdownlint: ~3s

**Validation** (slow):

- Custom validation: ~10s

**Total**: ~30-40s for all hooks on all files

### Optimizations

**Staged Files Only**:

- Only checks changed files
- ~5-15s instead of ~30-40s
- Default for automatic commits

**Parallel Execution**:

- Multiple hooks run in parallel
- Faster on multi-core systems

**Caching**:

- Pre-commit caches results
- Skip unchanged files
- Significantly faster on repeated runs

## Integration with Other Commands

### Before Committing

```bash
# Validate code
/nix-validate
Quick validation

# Run pre-commit hooks
/nix-precommit
Run staged

# Commit
git commit -m "feat: add feature"
```

### Before PR

```bash
# Run all hooks
/nix-precommit
Run all hooks

# Full validation
/nix-validate
Full validation

# Create PR
gh pr create
```

### With Auto-Fix

```bash
# Auto-fix issues
/nix-fix

# Verify with hooks
/nix-precommit
Run all hooks

# Should pass now
```

## Related Commands

- `/nix-fix` - Auto-fix issues found by hooks
- `/nix-validate` - Comprehensive validation
- `/review` - Code review before PR
- `/nix-test` - Test builds

---

**Pro Tip**: Install hooks immediately after cloning the repository:

```bash
cd /path/to/nixos-config
/nix-precommit
Install hooks
```

This ensures code quality from day one! 🔨
