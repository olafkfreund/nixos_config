# Deploy All Hosts with Testing

You are a NixOS deployment specialist. Deploy configuration changes to all hosts with comprehensive testing and monitoring.

## Task Overview

Execute a safe, tested deployment across all infrastructure hosts with proper validation and rollback procedures.

## Prerequisites Check

```bash
# 1. Check git status
git status

# Should show clean state or staged changes
# Unstaged changes should be intentional

# 2. Check for open critical issues
/check_tasks

# Resolve critical issues before deploying

# 3. Check monitoring health
grafana-status
prometheus-status

# Ensure monitoring operational for deployment tracking
```

## Deployment Workflow

### Step 1: Pre-Deployment Validation

```bash
# 1. Syntax validation
just check-syntax

# All files should parse correctly
# No syntax errors allowed

# 2. Configuration validation
just validate-quick

# Quick validation pass
# Catches obvious configuration errors

# 3. Module validation
just test-modules

# Verify module system integrity
```

### Step 2: Configuration Testing

**Test all hosts in parallel (recommended):**

```bash
# Fast parallel testing (~3 minutes)
just quick-test

# Shows real-time progress for all hosts
# Fails fast if any host has issues
```

**Or test sequentially (slower but detailed):**

```bash
# Test each host individually
just test-host p620
just test-host razer
just test-host p510
just test-host samsung

# Better for debugging specific host issues
```

**If any test fails:**
1. Review error messages carefully
2. Fix configuration issues
3. Re-run tests before proceeding
4. **DO NOT** deploy with failing tests

### Step 3: Review Changes

```bash
# Show what will change on each host
just diff p620
just diff razer
just diff p510
just diff samsung

# Review output carefully:
# - Service configuration changes
# - Package additions/removals
# - System option changes
# - Security implications
```

**Decision point:**
- If changes are expected: Proceed ✅
- If unexpected changes: Investigate first ⚠️
- If security concerns: Review carefully 🔒

### Step 4: Create Deployment Snapshot

```bash
# Document current state before deployment
mkdir -p docs/deployments/

cat > docs/deployments/deployment-$(date +%Y-%m-%d-%H%M).md <<EOF
# Deployment $(date +%Y-%m-%d %H:%M)

## Changes Being Deployed

$(git log --oneline -5)

## Affected Hosts

- P620: [description of changes]
- Razer: [description of changes]
- P510: [description of changes]
- Samsung: [description of changes]

## Testing Results

- Syntax validation: ✅
- Configuration tests: ✅
- All hosts build: ✅

## Current Generations

- P620: $(ssh p620 "readlink /nix/var/nix/profiles/system | grep -oP '\d+'")
- Razer: $(ssh razer "readlink /nix/var/nix/profiles/system | grep -oP '\d+'")
- P510: $(ssh p510 "readlink /nix/var/nix/profiles/system | grep -oP '\d+'")
- Samsung: $(ssh samsung "readlink /nix/var/nix/profiles/system | grep -oP '\d+'")

## Rollback Commands

If issues occur:
\`\`\`bash
ssh HOST "sudo nixos-rebuild switch --rollback"
\`\`\`
EOF
```

### Step 5: Execute Deployment

**Option A: Deploy to all hosts in parallel (fastest)**

```bash
# Deploy to all hosts simultaneously (~2 minutes)
just deploy-all-parallel

# Best for:
# - Tested changes
# - Non-critical updates
# - Time-sensitive deployments
```

**Option B: Smart deployment (recommended)**

```bash
# Deploy only to hosts with changes
just quick-deploy p620
just quick-deploy razer
just quick-deploy p510
just quick-deploy samsung

# Best for:
# - Partial configuration changes
# - Selective updates
# - Resource efficiency
```

**Option C: Sequential deployment (safest)**

```bash
# Deploy one host at a time
just p620    # Deploy and verify
just razer   # Deploy and verify
just p510    # Deploy and verify
just samsung # Deploy and verify

# Best for:
# - Major changes
# - High-risk updates
# - When monitoring between deploys
```

**Option D: Phased deployment (production-style)**

```bash
# Phase 1: Deploy to test host first
just quick-deploy samsung

# Monitor for 10 minutes
sleep 600

# Phase 2: Deploy to remaining mobile
just quick-deploy razer

# Monitor for 10 minutes
sleep 600

# Phase 3: Deploy to servers
just quick-deploy p510
just quick-deploy p620

# Best for:
# - Critical infrastructure changes
# - Potentially breaking updates
# - High-availability requirements
```

### Step 6: Post-Deployment Verification

**Immediate checks (run right after deployment):**

```bash
# 1. Check all hosts are reachable
just ping-hosts

# 2. Check for failed services
for host in p620 razer p510 samsung; do
  echo "=== $host Failed Services ==="
  ssh $host "systemctl --failed --no-pager"
done

# 3. Verify critical services
echo "=== P620 (Monitoring Server) ==="
ssh p620 "systemctl is-active prometheus grafana alertmanager"

echo "=== P510 (Media Server) ==="
ssh p510 "systemctl is-active plex nzbget"

echo "=== Razer & Samsung (Mobile) ==="
for host in razer samsung; do
  echo "=== $host ==="
  ssh $host "systemctl is-active node-exporter"
done

# 4. Check new generation numbers
for host in p620 razer p510 samsung; do
  echo "=== $host ==="
  ssh $host "readlink /nix/var/nix/profiles/system"
done
```

**Monitoring checks (5-10 minutes after):**

```bash
# 5. Check Prometheus targets
curl -s http://p620:9090/api/v1/targets | \
  jq '.data.activeTargets[] | select(.health != "up") | {instance: .labels.instance, health: .health}'

# Should show no unhealthy targets

# 6. Check Grafana dashboards
# Open: http://p620:3001
# Verify:
# - All host dashboards updating
# - No gaps in metrics
# - No unexpected spikes

# 7. Check for new alerts
curl -s http://p620:9093/api/v2/alerts | \
  jq '.[] | select(.status.state == "active") | {name: .labels.alertname, severity: .labels.severity}'

# Review any new firing alerts
```

**Extended monitoring (24 hours):**

```bash
# Monitor these metrics in Grafana:
# - System resource usage (CPU, memory, disk)
# - Service health and uptime
# - Network connectivity and latency
# - Boot time (if hosts reboot)
# - Application performance

# Set calendar reminder for 24h check
```

### Step 7: Handle Deployment Issues

**If a service fails to start:**

```bash
# 1. Check service status
ssh HOST "systemctl status SERVICE_NAME"

# 2. View recent logs
ssh HOST "journalctl -u SERVICE_NAME -n 100"

# 3. Check configuration
ssh HOST "systemctl cat SERVICE_NAME"

# 4. Attempt restart
ssh HOST "sudo systemctl restart SERVICE_NAME"

# 5. If restart fails, rollback
ssh HOST "sudo nixos-rebuild switch --rollback"
```

**If deployment fails:**

```bash
# 1. Review error message
# Look for specific failure reason

# 2. Check host connectivity
ping HOST

# 3. Try emergency deployment
just emergency-deploy HOST

# 4. If emergency fails, SSH and rollback
ssh HOST "sudo nixos-rebuild switch --rollback"
```

**If monitoring shows issues:**

```bash
# 1. Identify affected host
# Check which host has alerts/metrics issues

# 2. Check service logs
ssh HOST "journalctl -xe -n 200"

# 3. Rollback if serious
ssh HOST "sudo nixos-rebuild switch --rollback"

# 4. Create issue for investigation
/new_task
# Document the issue for later fix
```

### Step 8: Update Deployment Documentation

```bash
# Update deployment log
cat >> docs/deployments/deployment-$(date +%Y-%m-%d-%H%M).md <<EOF

## Deployment Results

### Successful Deployments
- P620: ✅ Generation [N]
- Razer: ✅ Generation [N]
- P510: ✅ Generation [N]
- Samsung: ✅ Generation [N]

### Failed Services
[List any services that failed, or "None"]

### Issues Encountered
[Describe any issues, or "None"]

### Rollbacks Performed
[List any rollbacks, or "None"]

### Monitoring Status
- Prometheus: ✅ All targets reporting
- Grafana: ✅ All dashboards updating
- Alertmanager: ✅ [No alerts / List alerts]

## Post-Deployment Actions

- [ ] Monitor for 24 hours
- [ ] Review metrics for anomalies
- [ ] Update documentation if needed
- [ ] Close related GitHub issues

## Notes
[Any additional observations or actions taken]
EOF
```

### Step 9: Git Housekeeping

```bash
# If deployment was for committed changes
git log -1 --oneline

# Tag the deployment if major release
git tag -a "deploy-$(date +%Y-%m-%d)" -m "Production deployment $(date +%Y-%m-%d)"
git push --tags

# Clean up old generations
for host in p620 razer p510 samsung; do
  echo "=== $host generation cleanup ==="
  ssh $host "nix-collect-garbage --delete-older-than 30d"
  ssh $host "nix-store --optimize"
done
```

### Step 10: Communication and Documentation

**Update relevant documentation:**

```bash
# If major changes deployed, update:
# - @.agent-os/product/roadmap.md
# - docs/UPDATE-TRACKING-SUMMARY.md
# - CHANGELOG.md (if maintaining one)
```

**Close related GitHub issues:**

```bash
# If deployment resolves issues
gh issue close ISSUE_NUM -c "Deployed in commit COMMIT_HASH. Verified operational across all hosts."
```

**Notify stakeholders if applicable:**

```markdown
# Deployment completed successfully

**Date:** $(date)
**Hosts:** P620, Razer, P510, Samsung
**Changes:** [Brief summary]
**Status:** ✅ All systems operational
**Monitoring:** No issues detected

Full deployment report: docs/deployments/deployment-$(date +%Y-%m-%d-%H%M).md
```

## Success Criteria

- [ ] All prerequisites checked and passed
- [ ] Configuration validated successfully
- [ ] All hosts tested and built successfully
- [ ] Changes reviewed and understood
- [ ] Deployment snapshot created
- [ ] All hosts deployed successfully
- [ ] No failed systemd services
- [ ] Critical services verified operational
- [ ] Monitoring stack healthy
- [ ] Prometheus targets all reporting
- [ ] No new firing alerts (or expected ones)
- [ ] Deployment documentation updated
- [ ] Git housekeeping completed
- [ ] Related issues closed or updated
- [ ] 24-hour monitoring scheduled

## Deployment Timing Best Practices

**Best times to deploy:**
- Weekday mornings (after checking systems)
- After comprehensive testing
- When available for monitoring
- When infrastructure is stable

**Avoid deploying:**
- Friday afternoons (limit weekend issues)
- Before holidays/vacations
- During known high-usage periods
- When monitoring is degraded
- When other infrastructure work ongoing

## Emergency Rollback

If critical issues arise:

```bash
# Fast rollback all hosts
for host in p620 razer p510 samsung; do
  echo "Rolling back $host"
  ssh $host "sudo nixos-rebuild switch --rollback" &
done
wait

# Verify rollback
for host in p620 razer p510 samsung; do
  echo "=== $host ==="
  ssh $host "readlink /nix/var/nix/profiles/system"
  ssh $host "systemctl --failed"
done

# Create incident report
/new_task
# Type: bug, Priority: critical
# Title: "Deployment YYYY-MM-DD rollback required"
```

## Documentation References

- @docs/PATTERNS.md - NixOS patterns
- @docs/GITHUB-WORKFLOW.md - Development workflow
- @.agent-os/product/roadmap.md - Current priorities

## Example Complete Workflow

```bash
# 1. Pre-flight checks
/check_tasks
git status
just check-syntax

# 2. Test all hosts
just quick-test

# 3. Review changes
just diff p620

# 4. Create deployment snapshot
mkdir -p docs/deployments/
vim docs/deployments/deployment-$(date +%Y-%m-%d-%H%M).md

# 5. Deploy (choose method)
just deploy-all-parallel  # Fast
# OR
just quick-deploy p620 && \
just quick-deploy razer && \
just quick-deploy p510 && \
just quick-deploy samsung  # Controlled

# 6. Verify immediately
for host in p620 razer p510 samsung; do
  ssh $host "systemctl --failed"
done

# 7. Check monitoring
grafana-status
prometheus-status

# 8. Update documentation
vim docs/deployments/deployment-$(date +%Y-%m-%d-%H%M).md

# 9. Schedule 24h check
echo "Check deployment: $(date -d '+1 day')" | tee /tmp/deployment-check.txt

# 10. Success!
echo "✅ Deployment complete. Monitor for 24 hours."
```
