# NixOS Smart Deployment

Complete deployment workflow with automatic validation, testing, and safety checks.

## 🚀 Quick Deploy

**Single command to rule them all:**

```
/nix-deploy
Deploy to p620
```

That's it! I'll handle everything automatically.

## What I'll Do (Automatically)

### Phase 1: Pre-Deployment Validation (30s)

```bash
# 1. Check Git Status
git status  # Identify changed files

# 2. Syntax Validation
just check-syntax  # Fast Nix syntax check

# BLOCKS deployment if critical issues found
```

**Automatic Abort If:**

- ❌ Syntax errors detected
- ❌ Critical anti-patterns found (mkIf true, root services, etc.)
- ❌ Evaluation-time secret reads

### Phase 2: Configuration Testing (45s)

```bash
# 4. Quick Validation
just validate-quick  # Essential checks only

# 5. Host-Specific Test Build
just test-host HOST  # Full configuration build test

# WARNS about issues but doesn't block
```

**Automatic Warning For:**

- ⚠️ Missing systemd hardening
- ⚠️ New open firewall ports
- ⚠️ Services without DynamicUser

### Phase 3: Smart Deployment (60s)

```bash

# 8. Deployment
just quick-deploy HOST  # Optimized deployment

# Check critical services started successfully
systemctl status SERVICE
```

**Automatic Rollback If:**

- ❌ Critical services fail to start
- ❌ Network connectivity lost
- ❌ System becomes unresponsive

### Phase 4: Post-Deployment Verification (15s)

```bash

# Verify SSH, Tailscale, DNS working
```

## Deployment Modes

### Standard (Default)

```
/nix-deploy
Deploy to p620
```

**Time**: ~2.5 minutes
**Safety**: Full validation and testing

### Fast (Skip Tests)

```
/nix-deploy
Fast deploy to p620
```

**Time**: ~1 minute
**Safety**: Syntax check only, use for minor changes

### Emergency (Skip Everything)

```
/nix-deploy
Emergency deploy to p620
```

**Time**: ~30 seconds
**Safety**: Direct deployment, use for critical fixes only

### All Hosts (Parallel)

```
/nix-deploy
Deploy to all hosts
```

**Time**: ~3 minutes (parallel)
**Safety**: Full validation, deploys to all 3 hosts simultaneously

## Update Operations (NEW!)

### Quick Update

```
/nix-deploy
Update system
```

**What it does**: Runs `nh os update` to update system packages
**Time**: ~2 minutes
**Safety**: Uses NH (Nix Helper) for safe system updates

### Update Flake Inputs

```
/nix-deploy
Update flake
```

**What it does**:

1. Updates all flake inputs (`nix flake update`)
2. Automatically deploys updated configuration
   **Time**: ~3 minutes
   **Safety**: Full validation + deployment

### Preview Updates

```
/nix-deploy
Preview updates for p620
```

**What it does**:

- Shows which packages will be updated
- Displays version changes (old → new)
- Lists newly available packages
- **Does NOT deploy** - preview only

**Time**: ~30 seconds
**Safety**: Read-only, no changes made

**Example Output**:

```
🔍 Previewing Updates for p620

Package Changes:
  firefox: 120.0 → 121.0
  linux: 6.6.1 → 6.6.3
  systemd: 254.9 → 254.10

New Packages Available:
  ✨ new-package-1.2.3
  ✨ another-tool-4.5.6

Total Changes: 15 packages to update
Storage Impact: +120MB
```

### Complete Update Workflow (Guided with Issue Checking)

```
/nix-deploy
Update workflow for p620
```

**What it does**:

1. **Parallel Safety Checks** (runs simultaneously):
   - **Issue Check**: Scans NixOS/nixpkgs GitHub for known bugs in your packages
   - **Preview**: Shows all package changes and versions
   - **Syntax Validation**: Checks configuration syntax
2. **Issue Analysis**: Reports critical/high/medium severity problems
3. **Confirm**: Asks for your approval based on findings
4. **Deploy**: Applies updates only if safe or approved
5. **Report**: Shows newly available packages and update results

**Time**: ~4 minutes
**Safety**: Interactive confirmation with intelligent issue detection

### Smart Update with Automatic Issue Detection (NEW!)

```
/nix-deploy
Smart update p620
```

**What it does**:

1. **Intelligent Pre-Check** (parallel execution):
   - Runs issue-checker agent automatically
   - Validates configuration syntax
   - Previews package changes
2. **Risk Assessment**:
   - **No issues**: Proceeds automatically with update
   - **Medium issues**: Shows warnings, asks for confirmation
   - **Critical issues**: Blocks update, suggests alternatives
3. **Conditional Deploy**:
   - Only updates if safe OR user explicitly confirms
   - Skips problematic packages if possible
   - Creates rollback point before applying
4. **Post-Update Verification**:
   - Checks services started successfully
   - Verifies no new issues introduced
   - Reports any problems immediately

**Time**: ~3-5 minutes (includes issue checking)
**Safety**: Maximum - combines issue detection + configuration validation

**Parallel Execution Strategy**:
The smart update runs multiple checks simultaneously:

- Thread 1: issue-checker agent scans for GitHub issues
- Thread 2: nix flake update downloads new package data
- Thread 3: Configuration syntax validation
- Thread 4: Preview package changes and versions

All results combine into a single risk assessment before proceeding.

**Example Workflow**:

**Rollback if needed**:

```bash
# Cancel during preview
Apply these updates? [y/N]: n
Updates cancelled. No changes made.

# Revert after deployment
mv flake.lock.backup flake.lock
/nix-deploy
Deploy to p620  # Restore previous versions
```

## Smart Features

### 1. Change Detection

```
Analyzing changes...
✓ 3 files modified: modules/services/monitoring.nix
✓ Deployment required: Configuration changed

Affected services:
  • prometheus.service (will restart)
  • grafana.service (no restart needed)

Continue with deployment? [Y/n]
```

### 2. Automatic Rollback

```
Deploying to p620...
✓ Configuration built successfully
✓ Activating new generation...
✗ Critical service failed: postgresql.service

AUTOMATIC ROLLBACK INITIATED
↩ Rolling back to generation 1234...
✓ System restored to previous state

Error: PostgreSQL failed to start
Check: journalctl -u postgresql -n 50
```

## Safety Guarantees

### Pre-Deployment Checks

- [x] Syntax validation (blocks)
- [x] Anti-pattern detection (blocks critical)
- [x] Security audit (warns)
- [x] Test build (blocks)
- [x] Change detection (informs)

### Deployment Protection

- [x] Automatic rollback on failure
- [x] Service health monitoring
- [x] Network connectivity verification
- [x] Resource usage tracking
- [x] Generation management

### Post-Deployment

- [x] Service status verification
- [x] Resource baseline comparison
- [x] Log analysis for errors
- [x] Performance monitoring

## Deployment Report

After each deployment:

## Integration with GitHub Workflow

**With Issue Tracking:**

```
# 1. Create issue
/new_task "Add PostgreSQL monitoring"

# 3. Deploy with issue reference
/nix-deploy
Deploy to p620 for issue #123

# 4. Auto-commit and PR
git commit -m "feat(monitoring): add postgres monitoring (#123)"
gh pr create --fill
```

## Error Recovery

**Common Issues and Automatic Fixes:**

1. **Service Failed to Start**

   ```
   ✗ postgresql.service failed

   Automatic Actions:
   1. Captured logs: journalctl -u postgresql -n 50
   2. Rolled back to previous generation
   3. Service status: restored

   Suggested Fix:
   Check postgresql configuration syntax
   ```

2. **Out of Disk Space**

3. **Network Timeout**

   ```
   ✗ SSH connection timed out

   Automatic Actions:
   1. Retrying with backoff (3 attempts)
   2. Checking Tailscale connection
   3. Building locally, will deploy when network recovers
   ```

## Performance Optimization

### Build Caching

- ✅ Uses P620 binary cache (p620:5000)
- ✅ Parallel builds enabled
- ✅ Only rebuilds changed components

### Network Optimization

- ✅ Local builds for large changes
- ✅ Delta deployment (only changed files)
- ✅ Compressed transfers

## Best Practices

1. **Use Standard Mode**: For all normal deployments
2. **Use Fast Mode**: For minor config tweaks, documentation
3. **Use Emergency**: Only for critical production fixes
4. **Review Report**: Always check warnings and recommendations
5. **Monitor Resources**: Watch for memory/disk usage trends

Ready to deploy? Just tell me:

- Which host (p620, p510, razer, or "all")
- Mode (standard/fast/emergency, or I'll choose best)
- Issue number (optional, for commit message)

Example:

```
/nix-deploy
Deploy to p620
```

That's all you need! I'll handle the rest. 🚀
