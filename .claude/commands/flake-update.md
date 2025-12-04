# NixOS Flake Update and System Switch

You are a NixOS system maintenance specialist. Update flake inputs and deploy changes following best practices.

## Task Overview

Perform a safe, tested flake update with proper validation and deployment across all hosts.

## Pre-Update Checks

1. **Check current system state:**
   ```bash
   /check_tasks  # Review any open issues first
   nix flake metadata  # Show current input versions
   git status  # Ensure clean working directory
   ```

2. **Review monitoring status:**
   ```bash
   grafana-status  # Check monitoring health
   prometheus-status  # Verify metrics collection
   ```

## Update Process

### Step 1: Update Flake Inputs

```bash
# Update all inputs
nix flake update

# Or update specific input only
# nix flake lock --update-input nixpkgs
# nix flake lock --update-input home-manager
# nix flake lock --update-input agenix
```

### Step 2: Review Changes

```bash
# Show what changed
git diff flake.lock

# Detailed comparison
nix flake metadata | tee /tmp/flake-before.txt
# After update:
nix flake metadata | diff /tmp/flake-before.txt -
```

**Identify:**
- Which inputs changed
- How many commits difference
- Any major version bumps
- Breaking changes in changelogs

### Step 3: Test Updates (CRITICAL)

```bash
# Validate syntax first
just check-syntax

# Quick validation
just validate-quick

# Test all hosts in parallel
just quick-test

# If quick-test fails, test individually:
just test-host p620
just test-host razer
just test-host p510
just test-host samsung
```

### Step 4: Deploy to Hosts

**Only if all tests pass!**

```bash
# Deploy to each host (only if configuration changed)
just quick-deploy p620
just quick-deploy razer
just quick-deploy p510
just quick-deploy samsung

# Or deploy to all hosts in parallel
just deploy-all-parallel
```

### Step 5: Post-Deployment Verification

```bash
# Check for failed services on each host
ssh p620 "systemctl --failed"
ssh razer "systemctl --failed"
ssh p510 "systemctl --failed"
ssh samsung "systemctl --failed"

# Verify critical services
ssh p620 "systemctl status prometheus grafana"
ssh p510 "systemctl status plex nzbget"

# Check monitoring dashboards
# Grafana: http://p620:3001
# Prometheus: http://p620:9090
```

### Step 6: Create Documentation Commit

```bash
# Stage the lock file
git add flake.lock

# Create detailed commit message
git commit -m "chore(flake): update inputs $(date +%Y-%m-%d)

Updated inputs:
- nixpkgs: [old commit] → [new commit] ([N commits])
- home-manager: [old] → [new] ([N commits])
- agenix: [old] → [new] ([N commits])
[list other significant changes]

Testing:
- All hosts built successfully
- No failed services after deployment
- Monitoring dashboards operational

Deployed to: p620, razer, p510, samsung"

# Push changes
git push
```

## Success Criteria

- [ ] Flake inputs updated successfully
- [ ] All hosts tested with `just quick-test`
- [ ] All hosts deployed without errors
- [ ] No failed systemd services
- [ ] Critical services verified operational
- [ ] Monitoring dashboards accessible
- [ ] Changes committed with detailed changelog
- [ ] No configuration drift detected

## Rollback Procedures

### If Build Fails During Testing

```bash
# Revert flake.lock
git checkout flake.lock

# Verify rollback
nix flake metadata
```

### If Deployment Causes Issues

```bash
# On affected host
sudo nixos-rebuild switch --rollback

# Or roll back to specific generation
nixos-rebuild switch --rollback --generation N
```

### If Service Failures Occur

```bash
# Check what failed
systemctl --failed

# View logs
journalctl -u SERVICE_NAME -n 50

# Rollback if needed
sudo nixos-rebuild switch --rollback
```

## Monitoring After Update

Monitor these for 24 hours after update:

1. **System Resources:**
   - CPU usage in Grafana
   - Memory consumption
   - Disk I/O patterns

2. **Service Health:**
   - All exporters reporting
   - No gaps in metrics
   - Alert rules functioning

3. **Boot Times:**
   - No significant boot time increase
   - All services starting correctly

4. **User Reports:**
   - Desktop environment stability
   - Application functionality
   - Network connectivity

## Common Issues and Solutions

### Issue: Hash Mismatch Errors

```bash
# Clear evaluation cache
nix-collect-garbage -d

# Retry build
just test-host HOST
```

### Issue: Conflicting Package Versions

```bash
# Check for conflicts
nix flake check --show-trace

# Review error message for conflicting packages
# Update overrides in flake.nix if needed
```

### Issue: Service Won't Start After Update

```bash
# Check service status
systemctl status SERVICE_NAME

# View detailed logs
journalctl -xeu SERVICE_NAME

# Check for configuration changes
systemctl cat SERVICE_NAME

# Rollback if configuration issue
sudo nixos-rebuild switch --rollback
```

## Documentation References

- @docs/PATTERNS.md - NixOS patterns and best practices
- @docs/NIXOS-ANTI-PATTERNS.md - Avoid these patterns
- @docs/GITHUB-WORKFLOW.md - Issue and PR workflow
- @.agent-os/product/roadmap.md - Current priorities

## Notes

- Always test before deploying to production hosts
- Keep old generations for at least 30 days
- Document any breaking changes in commit message
- Update roadmap if significant features added
- Create GitHub issue for tracking if major update

## Example Complete Workflow

```bash
# 1. Check status
/check_tasks
git status

# 2. Update
nix flake update

# 3. Review
git diff flake.lock

# 4. Test
just quick-test

# 5. Deploy
just deploy-all-parallel

# 6. Verify
for host in p620 razer p510 samsung; do
  ssh $host "systemctl --failed"
done

# 7. Commit
git add flake.lock
git commit -m "chore(flake): update inputs ..."
git push

# 8. Monitor
# Check Grafana dashboards for 24h
```
