# NixOS Update Checker - Complete Guide

> **Status**: Production Ready
> **Location**: `modules/services/nixos-update-checker/`
> **Deployed On**: P620
> **Last Updated**: 2025-12-03

## Overview

The NixOS Update Checker is a safe, transparent update management system that detects available updates without automatically applying them. It provides a three-stage workflow with manual control at each step.

## Quick Start

```bash
# Check for updates
nixos-check-updates --details

# Test updates (temporary, lost on reboot)
nixos-upgrade-test

# Apply updates permanently (with confirmation)
nixos-system-upgrade
```

## Architecture

### Three-Stage Workflow

```
1. DETECTION (Automated)
   ↓
   - Monthly systemd timer
   - Hash-based flake.lock comparison
   - Creates notification files
   ↓
2. TESTING (Manual)
   ↓
   - nixos-upgrade-test
   - Builds new configuration
   - Activates temporarily
   - Lost on reboot
   ↓
3. APPLICATION (Manual)
   ↓
   - nixos-system-upgrade
   - Requires "yes" confirmation
   - Creates new boot generation
   - Persists across reboots
```

### Detection Mechanism

**Hash-Based Change Detection:**

- Calculates SHA256 hash of `flake.lock`
- Compares with cached hash
- Detects when inputs have changed
- No external dependencies required

**Why Hash-Based?**

- Works with any Nix version
- No network access needed during check
- Deterministic and reliable
- Fast execution (< 1 second)

## Configuration

### Enable on a Host

```nix
# In hosts/HOSTNAME/configuration.nix
services.nixos-update-checker = {
  enable = true;
  flakeDir = "/home/olafkfreund/.config/nixos";
  checkInterval = "monthly";  # Options: daily, weekly, monthly
  enableMotd = false;  # MOTD disabled due to /etc/ immutability
};
```

### Required: Home Directory Permissions

If your flake is in a home directory, grant execute permission:

```bash
chmod o+x /home/username/
chmod o+x /home/username/.config/
```

**Why?** The service runs as `nixos-update-checker` user and needs to traverse directories to reach the flake.

## Usage

### 1. Check for Updates

```bash
# View detailed status
nixos-check-updates --details
```

**Output Example:**

```
=== NixOS Update Checker Status ===

Last check: 2025-12-03 19:01:14

Status: Updates available

NixOS Updates Available
----------------------
Checked: 2025-12-03 19:01:14

Flake inputs have been updated.

To test updates: nixos-upgrade-test
To apply updates: nixos-system-upgrade
```

### 2. Test Updates (Safe)

```bash
nixos-upgrade-test
```

**What It Does:**

1. Updates flake inputs (`nix flake update`)
2. Builds new configuration
3. Applies temporarily (`nixos-rebuild test`)
4. **Changes lost on reboot**

**Perfect For:**

- Testing new packages
- Verifying compatibility
- Checking for breaking changes
- Safe experimentation

### 3. Apply Updates (Permanent)

```bash
nixos-system-upgrade
```

**What It Does:**

1. Asks for confirmation (type "yes")
2. Updates flake inputs
3. Builds new configuration
4. Applies permanently (`nixos-rebuild switch`)
5. Creates new boot generation
6. Clears update notifications

**Warning:** This is permanent! Always test first.

### 4. Rollback if Needed

If something goes wrong after permanent upgrade:

```bash
# Option 1: Rollback to previous generation
sudo nixos-rebuild --rollback switch

# Option 2: Reboot and select previous generation in GRUB
sudo reboot
# Select older generation in boot menu
```

## Testing Workflow

### Complete Test Cycle

```bash
# 1. Simulate updates available
cd /home/olafkfreund/.config/nixos
nix flake update

# 2. Trigger detection
sudo systemctl start nixos-update-checker.service

# 3. Check status
nixos-check-updates --details

# 4. Test updates (temporary)
nixos-upgrade-test

# 5. Verify system works
# ... test your applications ...

# 6a. If satisfied, make permanent
nixos-system-upgrade

# 6b. If issues found, rollback
sudo nixos-rebuild --rollback switch
```

### Verification Steps

After testing updates:

1. **Check Services:**

   ```bash
   systemctl status
   journalctl -p err -b  # Check for errors
   ```

2. **Check Applications:**
   - Open browsers, terminals, editors
   - Test development tools
   - Verify custom scripts work

3. **Check System:**

   ```bash
   nix-store --verify --check-contents
   df -h  # Check disk space
   ```

## Monitoring

### Check Timer Status

```bash
# View timer schedule
systemctl list-timers nixos-update-checker.timer

# View service status
systemctl status nixos-update-checker.service

# View recent runs
sudo journalctl -u nixos-update-checker.service -n 50
```

### Log Files

**Check Log:**

```bash
tail -f /var/lib/nixos-update-checker/check.log
```

**Notification File:**

```bash
cat /var/lib/nixos-update-checker/updates-available
```

### Manual Trigger

```bash
# Force immediate check
sudo systemctl start nixos-update-checker.service

# View results
nixos-check-updates --details
```

## Troubleshooting

### Updates Not Detected

**Symptom:** `nixos-check-updates` shows "up to date" but you know there are updates.

**Solution:**

```bash
# 1. Check cache file
cat /var/lib/nixos-update-checker/flake.lock.cache

# 2. Force recalculation
sudo rm /var/lib/nixos-update-checker/flake.lock.cache

# 3. Trigger check
sudo systemctl start nixos-update-checker.service
```

### Permission Denied Errors

**Symptom:** Service logs show "Permission denied" or "No flake.lock found"

**Solution:**

```bash
# 1. Check permissions
ls -ld /home/olafkfreund/ /home/olafkfreund/.config/

# 2. Add execute permission
chmod o+x /home/olafkfreund/
chmod o+x /home/olafkfreund/.config/

# 3. Verify service can access
sudo -u nixos-update-checker ls /home/olafkfreund/.config/nixos/flake.lock
```

### Service Failing

**Symptom:** Service exits with errors

**Debug Steps:**

```bash
# 1. Check service status
systemctl status nixos-update-checker.service

# 2. View full logs
sudo journalctl -u nixos-update-checker.service -xe

# 3. Check log file
tail -50 /var/lib/nixos-update-checker/check.log

# 4. Test manually as service user
sudo -u nixos-update-checker /nix/store/.../nixos-check-updates
```

## Security

### Service Hardening

The update checker runs with comprehensive security:

```nix
serviceConfig = {
  # Isolation
  DynamicUser = false;  # Stable user for state
  PrivateTmp = true;
  ProtectSystem = "strict";
  ProtectHome = "read-only";

  # Capabilities
  NoNewPrivileges = true;
  ProtectKernelTunables = true;
  ProtectKernelModules = true;
  RestrictSUIDSGID = true;

  # Resources
  MemoryMax = "512M";
  TasksMax = 100;
  TimeoutSec = "10m";
};
```

### Why Dedicated User?

- **Least Privilege**: Service runs with minimal permissions
- **Audit Trail**: All actions logged under specific user
- **Resource Control**: Resource limits prevent runaway processes
- **Isolation**: Can't affect other system components

## Integration

### With Existing Workflow

The update checker complements your existing update process:

1. **Automatic Detection**: Monthly checks for updates
2. **Manual Testing**: You control when to test
3. **Manual Application**: You control when to apply
4. **Existing Tools**: Works with standard `nixos-rebuild`

### With Monitoring

If you re-enable Prometheus/Grafana:

```nix
# Future enhancement - Prometheus exporter
services.nixos-update-checker = {
  enable = true;
  prometheus.enable = true;  # When implemented
};
```

## Best Practices

### Update Workflow

1. **Monthly Reviews**: Check for updates monthly
2. **Test First**: Always use `nixos-upgrade-test` first
3. **Verify Thoroughly**: Test critical applications
4. **Small Batches**: Don't accumulate too many updates
5. **Document Issues**: Note any problems found during testing

### Safety Guidelines

1. **Never Skip Testing**: Always test before permanent upgrade
2. **Read Changelogs**: Check for breaking changes
3. **Backup Important Data**: Before major updates
4. **Keep Generations**: Don't cleanup recent generations
5. **Know Rollback**: Practice rollback procedure

### Maintenance

1. **Log Rotation**: Logs managed by systemd
2. **State Directory**: `/var/lib/nixos-update-checker/`
3. **Cache Cleanup**: Automatic, no manual intervention needed
4. **Timer Monitoring**: Check timer status monthly

## FAQ

**Q: Will updates be applied automatically?**
A: No. Detection is automatic, but testing and application are always manual.

**Q: What if I reboot after testing updates?**
A: The system reverts to the previous configuration. Test updates are not permanent.

**Q: Can I change the check frequency?**
A: Yes. Set `checkInterval = "weekly"` or `"daily"` in configuration.

**Q: How do I disable the update checker?**
A: Set `services.nixos-update-checker.enable = false;` and rebuild.

**Q: What happens if flake update fails?**
A: The service logs the error and exits. Notifications are not created.

**Q: Can I test updates on one host before others?**
A: Yes! That's recommended. Test on P620 first, then roll out to others.

## Advanced Usage

### Custom Check Intervals

```nix
services.nixos-update-checker = {
  enable = true;
  checkInterval = "weekly";  # or "daily", "*-*-01 03:00:00" (systemd format)
};
```

### Multiple Flake Directories

For managing multiple flake-based systems:

```nix
# Host 1
services.nixos-update-checker.flakeDir = "/etc/nixos";

# Host 2
services.nixos-update-checker.flakeDir = "/home/user/.config/nixos";
```

### Integration with CI/CD

```bash
#!/bin/bash
# ci-update-check.sh - Run in CI pipeline

# Check for updates
if nixos-check-updates --details | grep -q "Updates available"; then
  echo "Updates detected"
  exit 1  # Fail CI to notify
fi
```

## Related Documentation

- **Module Source**: `modules/services/nixos-update-checker/default.nix`
- **Detailed README**: `modules/services/nixos-update-checker/README.md`
- **Issue**: #9 (closed)
- **Commit**: b445cce37

## Support

**Logs Location:**

- Service logs: `journalctl -u nixos-update-checker.service`
- Check log: `/var/lib/nixos-update-checker/check.log`
- State directory: `/var/lib/nixos-update-checker/`

**Configuration Files:**

- Module: `modules/services/nixos-update-checker/default.nix`
- Host config: `hosts/p620/configuration.nix` (line 428)
- Service imports: `modules/services/default.nix` (line 31)
