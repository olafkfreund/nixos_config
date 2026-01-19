# Bug Fix Workflow

Quick bug fix cycle optimized for speed and reliability.

**Estimated Time:** 2-5 minutes total

## Workflow Steps

### 1. Identify or Create Issue (30 seconds)

**If issue exists:**

```bash
/check_tasks
# Find existing bug report (e.g., #67 "P510 boot delay")
```

**If no issue:**

```bash
/new_task "Fix P510 boot delay from fstrim service"
# Creates issue #67
```

### 2. Create Fix Branch (30 seconds)

```bash
gh issue develop 67 --checkout
# Creates: fix/67-p510-boot-delay
```

### 3. Edit Files & Auto-Fix Patterns (1 minute)

**Edit the problematic code:**

```bash
# Make your changes using your editor
# Example: Fix systemd service timing issue
```

**Auto-fix anti-patterns:**

```bash
/nix-fix
```

**What happens:**

- Detects `mkIf true` patterns → Converts to direct assignment
- Finds trivial wrappers → Removes unnecessary abstraction
- Checks secret handling → Fixes evaluation-time reads
- Reviews service security → Adds missing DynamicUser hardening
- Shows before/after diffs

### 4. Fast Deploy (1 minute)

```bash
/nix-deploy
Fast deploy to p510
```

**What happens:**

- Minimal validation (syntax check only)
- Skips full test suite for speed
- Deploys immediately
- Verifies service startup
- Automatic rollback on failure

**Use when:**

- ✅ Small, isolated change
- ✅ Already tested locally
- ✅ Time-sensitive fix
- ❌ Large refactoring
- ❌ Security-critical changes

### 5. Verify Fix (30 seconds)

**Check service status:**

```bash
systemctl status SERVICE
journalctl -u SERVICE --since "1 minute ago"
```

**Or verify specific fix:**

```bash
# Example: Check boot time improved
systemd-analyze blame
```

### 6. Commit & PR (1 minute)

```bash
git add .
git commit -m "fix(p510): resolve boot delay from fstrim service (#67)

Optimize fstrim service configuration to prevent 8+ minute
boot delays on P510 media server.

Changes:
- Adjust fstrim timer to run weekly instead of daily
- Set After=multi-user.target to prevent boot blocking
- Reduce CPU priority with CPUWeight=20

Fixes #67"

git push -u origin fix/67-p510-boot-delay
gh pr create --fill
```

**Commit format:**

- `fix(scope):` for bug fixes
- Reference issue: `(#67)`
- Explain the fix and why it works
- List specific changes
- Footer: `Fixes #67` (auto-closes issue)

### 7. Verify Closure (30 seconds)

```bash
/check_tasks
# Confirm issue #67 is linked to PR
```

## Time Breakdown

| Step            | Time       | Command                       |
| --------------- | ---------- | ----------------------------- |
| Identify issue  | 30 sec     | `/check_tasks` or `/new_task` |
| Create branch   | 30 sec     | `gh issue develop`            |
| Edit & auto-fix | 1 min      | Edit + `/nix-fix`             |
| Fast deploy     | 1 min      | `/nix-deploy` (fast mode)     |
| Verify fix      | 30 sec     | `systemctl status`            |
| Commit & PR     | 1 min      | `git commit && gh pr create`  |
| Verify closure  | 30 sec     | `/check_tasks`                |
| **TOTAL**       | **~5 min** | **Complete bug fix**          |

## Traditional Approach Comparison

**Without slash commands:**

- Identify issue: 5-10 minutes (searching logs, GitHub)
- Fix and test: 15-30 minutes (manual validation)
- Deploy: 10-15 minutes (full test suite, manual checks)
- **Total: 30-55 minutes**

**With slash commands:**

- Identify issue: 30 seconds (`/check_tasks`)
- Fix and test: 1 minute (`/nix-fix`)
- Deploy: 1 minute (`/nix-deploy` fast mode)
- **Total: ~5 minutes**

**Time saved: 83-91% reduction**

## Deployment Modes

### Fast Deploy (Recommended for Bug Fixes)

```bash
/nix-deploy
Fast deploy to p620
```

- Minimal validation
- Quick deployment
- Best for: Small fixes, isolated changes
- Time: ~1 minute

### Standard Deploy

```bash
/nix-deploy
Deploy to p620
```

- Full validation
- Security checks
- Best for: Medium changes, multiple files
- Time: ~2.5 minutes

### Emergency Deploy

```bash
/nix-deploy
Emergency deploy to p510
```

- No validation
- Immediate deployment
- Best for: Production outages only
- Time: ~30 seconds

## Best Practices

### DO ✅

- Check for existing issue first (`/check_tasks`)
- Use `/nix-fix` to catch anti-patterns
- Deploy with fast mode for quick iteration
- Test the fix immediately after deployment
- Link PR to issue (`Fixes #67`)

### DON'T ❌

- Skip creating/finding issue (tracking matters)
- Deploy untested changes to production
- Use emergency mode unless truly urgent
- Skip verification step
- Forget to check if fix actually works

## Common Bug Fix Patterns

### Service Fails to Start

```bash
# 1. Check status and logs
systemctl status SERVICE
journalctl -u SERVICE -n 50

# 2. Fix configuration
# Edit configuration file

# 3. Auto-fix patterns
/nix-fix

# 4. Fast deploy
/nix-deploy
Fast deploy to HOST

# 5. Verify
systemctl status SERVICE
```

### Boot Performance Issue

```bash
# 1. Analyze boot time
systemd-analyze blame
systemd-analyze critical-chain

# 2. Identify slow service
# Fix service configuration

# 3. Deploy and test
/nix-deploy
Fast deploy to HOST

# 4. Compare boot time
systemd-analyze blame
```

### Configuration Syntax Error

```bash
# 1. Check syntax
just check-syntax

# 2. Fix syntax errors
# Edit files

# 3. Validate
just validate-quick

# 4. Deploy
/nix-deploy
Fast deploy to HOST
```

## Troubleshooting

### Fix Doesn't Work

```bash
# Rollback immediately
sudo nixos-rebuild switch --rollback

# Review error logs
journalctl -xe

# Check what changed
just diff HOST
```

### Deploy Fails

```bash
# Check validation errors
just validate-quick

# Review specific errors
nix build .#nixosConfigurations.HOST.config.system.build.toplevel --show-trace

# Fix errors and retry
/nix-deploy
Fast deploy to HOST
```

### Service Still Broken

```bash
# Check service dependencies
systemctl list-dependencies SERVICE

# Review service configuration
systemctl cat SERVICE

# Check for conflicts
systemctl status SERVICE
journalctl -u SERVICE --since "5 minutes ago"
```

## Next Steps

After PR is merged:

1. Deploy to all affected hosts if necessary
2. Monitor for regressions
3. Update documentation if bug reveals pattern
4. Close issue (auto-closes with PR merge)

## Related Workflows

- `/nix-workflow-feature` - Feature development (5-10 minutes)
- `/nix-workflow-security` - Security audits (3-5 minutes)
- `/nix-help workflows` - All available workflows

---

**Pro Tip:** For recurring bugs, create a monitoring alert or add validation to catch them earlier. Use `/nix-module` to create a monitoring module.
