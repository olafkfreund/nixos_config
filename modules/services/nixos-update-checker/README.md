# NixOS Update Checker

A safe, transparent NixOS update management system that detects updates without automatically applying them, provides multi-channel notifications, and allows testing before permanent application.

## Features

- **Automated Detection**: Monthly systemd timer checks for flake input updates
- **Multi-Channel Notifications**:
  - File-based notifications (`/var/lib/nixos-update-checker/updates-available`)
  - System logs (`/var/lib/nixos-update-checker/check.log`)
  - MOTD integration (disabled by default - see Configuration)
- **Three-Stage Workflow**:
  1. **Detection**: Automatic monthly checks (non-invasive)
  2. **Testing**: Manual testing with `nixos-upgrade-test` (temporary, lost on reboot)
  3. **Application**: Manual permanent upgrade with `nixos-system-upgrade` (with confirmation)
- **Security Hardening**: DynamicUser, sandboxing, resource limits
- **No Prometheus Dependency**: Works with native NixOS tools

## Configuration

### Basic Enable

```nix
{
  services.nixos-update-checker = {
    enable = true;
  };
}
```

### Custom Configuration

```nix
{
  services.nixos-update-checker = {
    enable = true;
    flakeDir = "/path/to/your/flake";  # Default: /home/olafkfreund/.config/nixos
    checkInterval = "weekly";          # Default: monthly (also: daily, weekly)
    enableMotd = false;                # Default: false (see MOTD section below)
  };
}
```

### Important: Home Directory Permissions

If your flake directory is in a user's home directory (like `/home/username/.config/nixos`), you must grant execute permission for the service to traverse the directory:

```bash
chmod o+x /home/username/
chmod o+x /home/username/.config/
```

**Why?** The `nixos-update-checker` service runs as a dedicated system user and needs execute permission to traverse parent directories to reach the flake.

**Security Note:** This only grants traversal permission (execute), not read access to your home directory contents.

## Usage

### Check for Updates

```bash
# Check status and details
nixos-check-updates --details

# Trigger immediate check
nixos-check-updates
```

**Output:**

```
=== NixOS Update Checker Status ===

Last check: 2025-12-03 14:30:00
Status: Updates available ✓

NixOS Updates Available
======================
Checked: 2025-12-03 14:30:00

Flake inputs have been updated.

To test updates: nixos-upgrade-test
To apply updates: nixos-system-upgrade
```

### Test Updates (Temporary)

```bash
nixos-upgrade-test
```

This command will:

1. Update flake inputs
2. Build the new configuration
3. Apply it temporarily (using `nixos-rebuild test`)
4. Changes are lost on reboot

**Safe for testing!** You can verify everything works before making it permanent.

### Apply Updates (Permanent)

```bash
nixos-system-upgrade
```

This command will:

1. Ask for confirmation (requires typing "yes")
2. Update flake inputs
3. Build the new configuration
4. Apply it permanently (using `nixos-rebuild switch`)
5. Create new boot entry
6. Clear update notifications

**Important:** Always test first with `nixos-upgrade-test`!

## Workflow Example

```bash
# 1. System automatically checks for updates monthly
# (You see MOTD notification on login if updates available)

# 2. Check what updates are available
$ nixos-check-updates --details
Status: Updates available ✓

# 3. Test the updates first (safe, temporary)
$ nixos-upgrade-test
✅ Configuration tested successfully!

# 4. Verify everything works (browsers, applications, etc.)

# 5. If satisfied, apply permanently
$ nixos-system-upgrade
✅ System upgraded successfully!

# 6. Rollback if needed
$ nixos-rebuild --rollback switch
```

## Notifications

### MOTD (Message of the Day)

**Status:** Disabled by default due to NixOS `/etc/` immutability.

In NixOS, `/etc/` is managed declaratively and is read-only at runtime. Runtime services cannot create files in `/etc/motd.d/` even with systemd permissions.

**Alternative:** Check the notification file directly or monitor via logs:

```bash
cat /var/lib/nixos-update-checker/updates-available
```

**Future Enhancement:** MOTD support could be added through declarative NixOS configuration based on the service state file

### File-Based Notification

**Location:** `/var/lib/nixos-update-checker/updates-available`

Check this file exists to determine if updates are pending:

```bash
if [ -f /var/lib/nixos-update-checker/updates-available ]; then
  echo "Updates available"
fi
```

### System Logs

**Location:** `/var/lib/nixos-update-checker/check.log`

View recent logs:

```bash
tail -f /var/lib/nixos-update-checker/check.log
```

View service logs via journald:

```bash
journalctl -u nixos-update-checker.service -f
```

## Systemd Timer

The update checker runs on a systemd timer.

### Check Timer Status

```bash
systemctl status nixos-update-checker.timer
```

### View Next Scheduled Check

```bash
systemctl list-timers nixos-update-checker.timer
```

### Manually Trigger Check

```bash
sudo systemctl start nixos-update-checker.service
```

## Security

The update checker service runs with comprehensive security hardening:

- **Dedicated User**: Runs as `nixos-update-checker` user (non-root)
- **Sandboxing**:
  - `PrivateTmp=true`
  - `ProtectSystem=strict`
  - `ProtectHome=read-only` (allows read access to flake directory)
- **Resource Limits**:
  - `MemoryMax=512M`
  - `TasksMax=100`
  - `TimeoutSec=10m`
- **Capability Restrictions**:
  - `NoNewPrivileges=true`
  - `RestrictSUIDSGID=true`
  - `RestrictRealtime=true`

## Troubleshooting

### No Updates Showing (But You Know There Are Updates)

```bash
# Force a fresh check
sudo systemctl restart nixos-update-checker.service

# Check service logs
sudo journalctl -u nixos-update-checker.service -n 50
```

### Service Failing

```bash
# Check service status
sudo systemctl status nixos-update-checker.service

# View full logs
sudo journalctl -u nixos-update-checker.service -xe

# Check permissions
ls -la /var/lib/nixos-update-checker/
```

### Permission Denied Errors

If the service logs show "Permission denied" or "No flake.lock found":

```bash
# Check home directory permissions
ls -ld /home/username/ /home/username/.config/

# Add execute permission for traversal
chmod o+x /home/username/
chmod o+x /home/username/.config/

# Restart service
sudo systemctl restart nixos-update-checker.service
```

### Flake Directory Not Found

Ensure your `flakeDir` configuration points to the correct location:

```nix
services.nixos-update-checker.flakeDir = "/path/to/your/flake";
```

## Comparison with system.autoUpgrade

| Feature                  | autoUpgrade  | update-checker                |
| ------------------------ | ------------ | ----------------------------- |
| **Auto-applies updates** | ✅ Yes       | ❌ No (manual)                |
| **Notification**         | ❌ No        | ✅ MOTD, files, logs          |
| **Testing phase**        | ❌ No        | ✅ Yes (`nixos-upgrade-test`) |
| **User control**         | ❌ Automatic | ✅ Full control               |
| **Rollback-friendly**    | ⚠️ Reactive  | ✅ Proactive                  |
| **Audit trail**          | ⚠️ Limited   | ✅ Comprehensive logs         |

## Design Philosophy

1. **Never Auto-Apply**: Updates are detected but never automatically applied
2. **Test Before Commit**: Always provide a safe testing mechanism
3. **User Awareness**: Multiple notification channels ensure visibility
4. **Audit Trail**: Comprehensive logging for troubleshooting
5. **Security First**: Hardened service with minimal privileges

## Integration with Existing Infrastructure

This module integrates seamlessly with your existing NixOS infrastructure:

- **Works with flakes**: Detects flake input changes
- **Uses native tools**: `nix flake update`, `nixos-rebuild`
- **No external dependencies**: No Prometheus/Grafana requirement
- **Respects existing config**: Doesn't interfere with manual updates

## Credits

Inspired by [Hyper-NixOS update checker](https://github.com/yourusername/hyper-nixos) with adaptations for simplified infrastructure and enhanced security.

## License

Part of the NixOS Infrastructure Hub. See repository LICENSE for details.
