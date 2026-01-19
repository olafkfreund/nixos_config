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

# 3. Anti-Pattern Detection
# Scan changed files for anti-patterns
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

# 6. Security Audit
# Run security checks on changed modules
# WARNS about issues but doesn't block
```

**Automatic Warning For:**

- ⚠️ Missing systemd hardening
- ⚠️ New open firewall ports
- ⚠️ Services without DynamicUser

### Phase 3: Smart Deployment (60s)

```bash
# 7. Change Detection
# Compare current vs new configuration
# SKIPS deployment if no changes

# 8. Deployment
just quick-deploy HOST  # Optimized deployment

# 9. Service Verification
# Check critical services started successfully
systemctl status SERVICE
```

**Automatic Rollback If:**

- ❌ Critical services fail to start
- ❌ Network connectivity lost
- ❌ System becomes unresponsive

### Phase 4: Post-Deployment Verification (15s)

```bash
# 10. Service Health Check
# Verify all enabled services running

# 11. Resource Monitoring
# Check memory, CPU, disk usage

# 12. Network Connectivity
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
**Safety**: Full validation, deploys to all 4 hosts simultaneously

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

**Example Issue Check Output**:

```
🔍 Checking for Known Issues (Parallel)...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Scanning 1,247 installed packages...
🔍 Querying GitHub issues...
📊 Correlating with your system...

🚨 CRITICAL SEVERITY (1 package)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Package: systemd-254.6
   Issue: #250123 - systemd 254.x fails to boot on UEFI
   https://github.com/NixOS/nixpkgs/issues/250123

⚠️ HIGH SEVERITY (1 package)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Package: linux-6.6.1
   Issue: #248999 - NVIDIA driver incompatible

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Recommendation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⛔ DO NOT UPDATE
   1 critical issue detected.
   Wait for fixes or consider pinning systemd to 253.x

Continue anyway? (NOT recommended) [y/N]:
```

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

```
📦 Starting Complete Update Workflow for p620

Step 1: Previewing updates...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
firefox: 120.0 → 121.0
linux: 6.6.1 → 6.6.3
... (13 more packages)

Apply these updates? [y/N]: y

Step 2: Backing up flake.lock...
✓ Backup saved: flake.lock.backup

Step 3: Deploying updates...
✓ Configuration built
✓ Activation successful
✓ Services verified

Step 4: Checking for new packages...
✨ 3 new packages available in nixpkgs

✅ Update Complete!
Time: 3min 45s
```

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

### 3. Resource Monitoring

```
Deployment successful! Monitoring system...

Resource Usage:
  Memory: 8.2GB / 16GB (51%) [+2% from baseline]
  CPU: 15% average (normal)
  Disk: 285GB / 500GB (57%)

Service Status:
  ✓ All 23 enabled services running
  ⚠ Warning: myservice using 800MB (limit: 1GB)

Network:
  ✓ SSH accessible
  ✓ Tailscale connected
  ✓ DNS resolving
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

```
╔════════════════════════════════════════════════╗
║         DEPLOYMENT REPORT: p620                ║
╚════════════════════════════════════════════════╝

✅ Deployment Status: SUCCESS
⏱  Total Time: 2m 45s
🔢 Generation: 1235 → 1236

📝 Changes Applied:
  • Modified: modules/services/monitoring.nix
  • Services Affected: prometheus, grafana, alertmanager
  • Services Restarted: prometheus (0.8s)

🔍 Pre-Deployment:
  ✓ Syntax validation (5s)
  ✓ Anti-pattern check (3s)
  ⚠ Security audit: 1 warning (see below)
  ✓ Test build (45s)
  ✓ Change detection: configuration changed

📦 Deployment:
  ✓ Build time: 38s
  ✓ Activation: 4s
  ✓ Service restarts: 1s

✅ Post-Deployment:
  ✓ All services healthy
  ✓ Network connectivity verified
  ✓ Resources within limits
  ✓ No errors in logs

⚠️  Warnings:
  1. Prometheus memory usage at 85% (850MB/1GB)
     Consider: increasing MemoryMax to 2GB

📊 System Status:
  Memory: 8.2GB / 16GB (51%)
  CPU: 15% average
  Disk: 285GB / 500GB (57%)
  Services: 23/23 running

💡 Recommendations:
  • Monitor prometheus memory usage
  • Consider garbage collection (last: 5 days ago)

✅ Deployment completed successfully!
```

## Integration with GitHub Workflow

**With Issue Tracking:**

```
# 1. Create issue
/new_task "Add PostgreSQL monitoring"

# 2. Make changes
# ... edit files ...

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

   ```
   ✗ Build failed: no space left on device

   Automatic Actions:
   1. Running garbage collection: nix-collect-garbage -d
   2. Freed: 12.5GB
   3. Retrying build...
   ✓ Build succeeded after cleanup
   ```

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

### Time Breakdown

```
Standard Deployment: 2.5 minutes
├─ Validation: 30s (parallel checks)
├─ Test Build: 45s (with cache)
├─ Deployment: 60s (optimized)
└─ Verification: 15s (health checks)

Fast Deployment: 1 minute
├─ Syntax Check: 5s
├─ Smart Detection: 10s
├─ Deployment: 30s
└─ Verification: 15s

Emergency: 30 seconds
├─ Direct Deploy: 20s
└─ Quick Check: 10s
```

## Best Practices

1. **Use Standard Mode**: For all normal deployments
2. **Use Fast Mode**: For minor config tweaks, documentation
3. **Use Emergency**: Only for critical production fixes
4. **Review Report**: Always check warnings and recommendations
5. **Monitor Resources**: Watch for memory/disk usage trends

Ready to deploy? Just tell me:

- Which host (p620, p510, razer, samsung, or "all")
- Mode (standard/fast/emergency, or I'll choose best)
- Issue number (optional, for commit message)

Example:

```
/nix-deploy
Deploy to p620
```

That's all you need! I'll handle the rest. 🚀
