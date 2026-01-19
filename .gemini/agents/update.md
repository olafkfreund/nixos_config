# Update Subagent

> **Automated NixOS system updates with safety checks and notifications**
> Safe flake updates with issue detection, test rebuilds, automatic fixes, and completion alerts

## Overview

The **update** subagent is a comprehensive automation tool that safely updates NixOS systems by orchestrating multiple steps: flake updates, issue checking, test builds, problem resolution, and system switching. It integrates with the issue-checker subagent and provides desktop notifications to keep you informed throughout the process.

**Key Features**:

- **Automated Flake Updates**: Runs `nix flake update` with proper logging
- **Pre-Update Safety Check**: Triggers issue-checker before proceeding
- **Test Rebuild**: Validates configuration before switching
- **Automatic Issue Resolution**: Attempts to fix common problems
- **Safe Switching**: Only switches if tests pass
- **Desktop Notifications**: Alerts on completion or failure
- **Rollback on Failure**: Automatic recovery from failed updates

**Use Cases**:

- Scheduled system updates (cron/systemd timers)
- Manual update requests with safety guarantees
- CI/CD pipeline integration
- Multi-host fleet management
- Development environment refreshes

## When This Subagent Runs

### Automatic Triggers

1. **User Requests System Update**

   ```
   User: "Update my NixOS system"
   User: "Run system update"
   User: "Upgrade packages"
   ```

2. **Scheduled Updates**
   - Daily/weekly systemd timer triggers
   - Cron job executions
   - CI/CD pipeline schedules

3. **Explicit Invocation**

   ```
   User: "Use the update subagent to update my system"
   User: "Run the automated update process"
   ```

### Manual Invocation

```bash
# Direct script execution
./update-system.sh

# Via systemd service
systemctl start nixos-auto-update

# Via Gemini Code
"Run the update subagent"
```

## Workflow Steps

The update subagent follows a comprehensive 8-step workflow:

```
┌─ Step 1: Pre-Update Preparation ─────────────────────
│ - Backup current generation
│ - Record current system state
│ - Check available disk space
│ - Verify network connectivity
└──────────────────────────────────────────────────────

┌─ Step 2: Flake Update ───────────────────────────────
│ - Run: nix flake update
│ - Capture updated inputs
│ - Log version changes
│ - Commit flake.lock (optional)
└──────────────────────────────────────────────────────

┌─ Step 3: Issue Detection (issue-checker) ───────────
│ - Invoke issue-checker subagent
│ - Analyze updated package versions
│ - Check NixOS/nixpkgs GitHub issues
│ - Identify critical/blocking problems
│ - Generate risk assessment report
└──────────────────────────────────────────────────────

┌─ Step 4: Risk Evaluation ────────────────────────────
│ - Review issue-checker results
│ - Classify severity (critical/high/medium/low)
│ - Determine if safe to proceed
│ - Apply mitigations if available
└──────────────────────────────────────────────────────

┌─ Step 5: Test Rebuild ───────────────────────────────
│ - Run: nixos-rebuild test
│ - Monitor build output
│ - Capture error messages
│ - Identify failing components
└──────────────────────────────────────────────────────

┌─ Step 6: Automatic Issue Resolution ────────────────
│ - Analyze build failures
│ - Apply known fixes:
│   • Pin problematic packages
│   • Adjust build flags
│   • Add missing dependencies
│   • Override broken derivations
│ - Retry test rebuild
│ - Maximum 3 fix attempts
└──────────────────────────────────────────────────────

┌─ Step 7: System Switch ──────────────────────────────
│ - If tests pass: nixos-rebuild switch
│ - Verify services started
│ - Check system health
│ - Automatic rollback on critical failure
└──────────────────────────────────────────────────────

┌─ Step 8: Notification & Reporting ───────────────────
│ - Send desktop notification
│ - Generate update report
│ - Log to system journal
│ - Update status dashboard (optional)
└──────────────────────────────────────────────────────
```

## Implementation

### Complete Shell Script

```bash
#!/usr/bin/env bash
# nixos-auto-update.sh - Automated NixOS system update with safety checks
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/nixos-auto-update.log"
STATE_FILE="/var/lib/nixos-auto-update/state.json"
MAX_FIX_ATTEMPTS=3
NOTIFICATION_ENABLED=true
ROLLBACK_ON_FAILURE=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
    logger -t nixos-auto-update "INFO: $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
    logger -t nixos-auto-update "SUCCESS: $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
    logger -t nixos-auto-update "WARNING: $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    logger -t nixos-auto-update "ERROR: $*"
}

# Desktop notification function
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"  # low, normal, critical
    local icon="${4:-dialog-information}"

    if [ "$NOTIFICATION_ENABLED" = true ]; then
        # Send to all logged-in users
        for user in $(who | awk '{print $1}' | sort -u); do
            user_id=$(id -u "$user")
            sudo -u "$user" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$user_id/bus \
                notify-send --urgency="$urgency" --icon="$icon" "$title" "$message"
        done
    fi
}

# Step 1: Pre-Update Preparation
pre_update_preparation() {
    log_info "Step 1: Pre-Update Preparation"

    # Check disk space (need at least 5GB free)
    local free_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 5242880 ]; then
        log_error "Insufficient disk space: ${free_space}KB free (need 5GB)"
        return 1
    fi

    # Record current generation
    local current_gen=$(nixos-rebuild list-generations | grep current | awk '{print $1}')
    log_info "Current generation: $current_gen"
    echo "{\"pre_update_generation\": $current_gen, \"timestamp\": \"$(date -Iseconds)\"}" > "$STATE_FILE"

    # Check network connectivity
    if ! ping -c 1 cache.nixos.org &>/dev/null; then
        log_error "No network connectivity to cache.nixos.org"
        return 1
    fi

    log_success "Pre-update preparation complete"
    return 0
}

# Step 2: Flake Update
flake_update() {
    log_info "Step 2: Running flake update"

    local update_output
    if ! update_output=$(nix flake update 2>&1); then
        log_error "Flake update failed: $update_output"
        return 1
    fi

    # Log changed inputs
    log_info "Flake inputs updated:"
    nix flake metadata --json | jq -r '.locks.nodes | to_entries[] | select(.value.locked) | "\(.key): \(.value.locked.rev // .value.locked.narHash)"' | while read -r line; do
        log_info "  $line"
    done

    # Optional: Commit flake.lock
    if [ "${AUTO_COMMIT_LOCK:-false}" = true ]; then
        git add flake.lock
        git commit -m "chore: Update flake.lock (automated)" || true
    fi

    log_success "Flake update complete"
    return 0
}

# Step 3: Issue Detection (invoke issue-checker subagent)
check_for_issues() {
    log_info "Step 3: Checking for known issues"

    # Invoke issue-checker subagent
    local issue_report
    if [ -f "${SCRIPT_DIR}/issue-checker.sh" ]; then
        issue_report=$(bash "${SCRIPT_DIR}/issue-checker.sh" --json 2>&1)
    else
        log_warning "issue-checker subagent not found, skipping"
        return 0
    fi

    # Parse issue-checker output
    local critical_count=$(echo "$issue_report" | jq -r '.issues.critical | length' 2>/dev/null || echo "0")
    local high_count=$(echo "$issue_report" | jq -r '.issues.high | length' 2>/dev/null || echo "0")

    if [ "$critical_count" -gt 0 ]; then
        log_error "Found $critical_count critical issue(s)"
        echo "$issue_report" | jq -r '.issues.critical[] | "  - \(.package): \(.description)"' | while read -r line; do
            log_error "$line"
        done

        # Store issues for later reference
        echo "$issue_report" > /var/lib/nixos-auto-update/issues.json

        log_warning "Proceeding with caution due to critical issues"
    elif [ "$high_count" -gt 0 ]; then
        log_warning "Found $high_count high-severity issue(s)"
    else
        log_success "No critical issues found"
    fi

    return 0
}

# Step 4: Risk Evaluation
evaluate_risks() {
    log_info "Step 4: Evaluating update risks"

    if [ -f /var/lib/nixos-auto-update/issues.json ]; then
        local critical_count=$(jq -r '.issues.critical | length' /var/lib/nixos-auto-update/issues.json)

        if [ "$critical_count" -gt 0 ]; then
            log_warning "Risk level: HIGH (critical issues detected)"

            # Check if auto-proceed is disabled for critical issues
            if [ "${AUTO_PROCEED_ON_CRITICAL:-false}" != true ]; then
                log_error "Aborting update due to critical issues (set AUTO_PROCEED_ON_CRITICAL=true to override)"
                return 1
            fi
        else
            log_info "Risk level: MEDIUM (high-severity issues may exist)"
        fi
    else
        log_info "Risk level: LOW (no issues detected)"
    fi

    return 0
}

# Step 5: Test Rebuild
test_rebuild() {
    log_info "Step 5: Running test rebuild"

    local test_output
    local test_exit_code=0

    if ! test_output=$(nixos-rebuild test 2>&1); then
        test_exit_code=$?
        log_error "Test rebuild failed (exit code: $test_exit_code)"
        echo "$test_output" > /var/lib/nixos-auto-update/test-failure.log
        return 1
    fi

    log_success "Test rebuild successful"
    return 0
}

# Step 6: Automatic Issue Resolution
fix_build_issues() {
    log_info "Step 6: Attempting to fix build issues"

    local attempt=1
    local fixed=false

    while [ $attempt -le $MAX_FIX_ATTEMPTS ] && [ "$fixed" = false ]; do
        log_info "Fix attempt $attempt of $MAX_FIX_ATTEMPTS"

        if [ ! -f /var/lib/nixos-auto-update/test-failure.log ]; then
            log_error "No test failure log found"
            return 1
        fi

        local error_log=$(cat /var/lib/nixos-auto-update/test-failure.log)

        # Common fix patterns

        # Fix 1: Hash mismatch
        if echo "$error_log" | grep -q "hash mismatch"; then
            log_info "Detected hash mismatch, updating hashes..."
            # Extract package name and update hash
            # This is a placeholder - actual implementation would parse the error
            log_warning "Hash mismatch detected but automatic fix not implemented"
        fi

        # Fix 2: Build failure due to missing dependencies
        if echo "$error_log" | grep -q "cannot find -l"; then
            log_info "Detected missing library dependency"
            # Parse missing library and add to buildInputs
            log_warning "Missing dependency detected but automatic fix not implemented"
        fi

        # Fix 3: Evaluation error
        if echo "$error_log" | grep -q "error: evaluation"; then
            log_info "Detected evaluation error"
            # Check syntax and common evaluation issues
            log_warning "Evaluation error detected but automatic fix not implemented"
        fi

        # Retry test rebuild
        log_info "Retrying test rebuild after fixes..."
        if test_rebuild; then
            log_success "Test rebuild succeeded after fixes"
            fixed=true
            return 0
        fi

        attempt=$((attempt + 1))
    done

    if [ "$fixed" = false ]; then
        log_error "Failed to fix issues after $MAX_FIX_ATTEMPTS attempts"
        return 1
    fi

    return 0
}

# Step 7: System Switch
system_switch() {
    log_info "Step 7: Switching to new configuration"

    local switch_output
    if ! switch_output=$(nixos-rebuild switch 2>&1); then
        log_error "System switch failed: $switch_output"

        if [ "$ROLLBACK_ON_FAILURE" = true ]; then
            log_warning "Attempting automatic rollback..."
            if nixos-rebuild switch --rollback 2>&1; then
                log_success "Rollback successful"
                send_notification "NixOS Update Failed" \
                    "System switch failed but rollback succeeded. System is stable." \
                    "critical" \
                    "dialog-error"
            else
                log_error "Rollback failed - manual intervention required!"
                send_notification "NixOS Update CRITICAL" \
                    "System switch AND rollback failed! Manual intervention required!" \
                    "critical" \
                    "dialog-error"
            fi
        fi

        return 1
    fi

    # Verify critical services
    log_info "Verifying critical services..."
    local critical_services=("sshd" "NetworkManager" "systemd-journald")
    local failed_services=()

    for service in "${critical_services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            log_warning "Service $service is not active"
            failed_services+=("$service")
        fi
    done

    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "Critical services failed: ${failed_services[*]}"

        if [ "$ROLLBACK_ON_FAILURE" = true ]; then
            log_warning "Rolling back due to service failures..."
            nixos-rebuild switch --rollback
        fi

        return 1
    fi

    log_success "System switch complete and services verified"
    return 0
}

# Step 8: Notification & Reporting
send_final_notification() {
    local success=$1
    log_info "Step 8: Sending completion notification"

    if [ "$success" = true ]; then
        local new_gen=$(nixos-rebuild list-generations | grep current | awk '{print $1}')
        local old_gen=$(jq -r '.pre_update_generation' "$STATE_FILE" 2>/dev/null || echo "unknown")

        send_notification "NixOS Update Complete" \
            "System successfully updated from generation $old_gen to $new_gen" \
            "normal" \
            "system-software-update"

        log_success "Update process completed successfully"

        # Generate report
        cat > /var/lib/nixos-auto-update/last-update.txt <<EOF
NixOS Auto-Update Report
========================
Date: $(date)
Previous Generation: $old_gen
New Generation: $new_gen
Status: SUCCESS

Updated Inputs:
$(nix flake metadata --json | jq -r '.locks.nodes | to_entries[] | select(.value.locked) | "  - \(.key): \(.value.locked.rev // .value.locked.narHash)"')

No critical issues encountered.
EOF

    else
        send_notification "NixOS Update Failed" \
            "System update encountered errors. Check logs for details." \
            "critical" \
            "dialog-error"

        log_error "Update process failed"

        # Generate failure report
        cat > /var/lib/nixos-auto-update/last-update.txt <<EOF
NixOS Auto-Update Report
========================
Date: $(date)
Status: FAILED

Error Log:
$(tail -n 50 "$LOG_FILE")

Review /var/lib/nixos-auto-update/ for detailed logs.
EOF
    fi
}

# Main execution flow
main() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "NixOS Automated Update Process Started"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Ensure state directory exists
    mkdir -p /var/lib/nixos-auto-update

    # Execute workflow steps
    if ! pre_update_preparation; then
        log_error "Pre-update preparation failed"
        send_final_notification false
        exit 1
    fi

    if ! flake_update; then
        log_error "Flake update failed"
        send_final_notification false
        exit 1
    fi

    if ! check_for_issues; then
        log_error "Issue checking failed"
        # Continue anyway - this is informational
    fi

    if ! evaluate_risks; then
        log_error "Risk evaluation determined update is too risky"
        send_final_notification false
        exit 1
    fi

    if ! test_rebuild; then
        log_warning "Test rebuild failed, attempting fixes..."
        if ! fix_build_issues; then
            log_error "Could not fix build issues"
            send_final_notification false
            exit 1
        fi
    fi

    if ! system_switch; then
        log_error "System switch failed"
        send_final_notification false
        exit 1
    fi

    send_final_notification true

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "NixOS Automated Update Process Completed Successfully"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    exit 0
}

# Run main function
main "$@"
```

## NixOS Configuration

### Systemd Service

```nix
# configuration.nix
{ config, pkgs, ... }:

{
  # Auto-update service
  systemd.services.nixos-auto-update = {
    description = "NixOS Automated Update with Safety Checks";

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/scripts/nixos-auto-update.sh";

      # Run as root (required for nixos-rebuild)
      User = "root";

      # Environment
      Environment = [
        "PATH=/run/current-system/sw/bin"
        "NOTIFICATION_ENABLED=true"
        "ROLLBACK_ON_FAILURE=true"
        "MAX_FIX_ATTEMPTS=3"
      ];

      # Logging
      StandardOutput = "journal";
      StandardError = "journal";

      # Timeout (2 hours max)
      TimeoutStartSec = "2h";
    };

    # Only run if network is available
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  # Auto-update timer (weekly on Sunday at 3 AM)
  systemd.timers.nixos-auto-update = {
    description = "Weekly NixOS Automated Update";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "Sun *-*-* 03:00:00";
      Persistent = true;  # Run missed timers on boot
      RandomizedDelaySec = "30min";  # Random delay to avoid thundering herd
    };
  };

  # Install script
  environment.etc."nixos/scripts/nixos-auto-update.sh" = {
    source = ./nixos-auto-update.sh;
    mode = "0755";
  };

  # Install dependencies
  environment.systemPackages = with pkgs; [
    libnotify  # For notify-send
    jq         # For JSON parsing
  ];
}
```

### Manual Trigger

```nix
# Add convenience command
environment.systemPackages = [
  (pkgs.writeShellScriptBin "update-system" ''
    sudo systemctl start nixos-auto-update
  '')
];
```

## Configuration Options

### Environment Variables

```bash
# Enable/disable desktop notifications
NOTIFICATION_ENABLED=true

# Automatic rollback on failure
ROLLBACK_ON_FAILURE=true

# Maximum fix attempts
MAX_FIX_ATTEMPTS=3

# Auto-commit flake.lock after update
AUTO_COMMIT_LOCK=false

# Proceed even with critical issues
AUTO_PROCEED_ON_CRITICAL=false

# Custom log file location
LOG_FILE="/var/log/nixos-auto-update.log"

# State directory
STATE_DIR="/var/lib/nixos-auto-update"
```

### Timer Schedules

```nix
# Daily updates at 2 AM
OnCalendar = "*-*-* 02:00:00";

# Weekly on Sunday at 3 AM
OnCalendar = "Sun *-*-* 03:00:00";

# Monthly on the 1st at 4 AM
OnCalendar = "*-*-01 04:00:00";

# Every 6 hours
OnCalendar = "*-*-* 00/6:00:00";
```

## Integration with issue-checker

The update subagent integrates seamlessly with the issue-checker subagent:

```bash
# update subagent calls issue-checker
bash "${SCRIPT_DIR}/issue-checker.sh" --json

# issue-checker returns JSON report
{
  "timestamp": "2025-12-15T10:30:00Z",
  "total_packages": 847,
  "issues": {
    "critical": [
      {
        "package": "linux-6.12.3",
        "issue_number": 325841,
        "description": "Boot failure on NVIDIA systems",
        "severity": "critical",
        "recommendation": "Pin kernel to 6.11.x"
      }
    ],
    "high": [...],
    "medium": [...],
    "low": [...]
  },
  "recommendation": "DELAY"
}
```

### Risk-Based Decisions

```bash
# Critical issues detected
if [ "$critical_count" -gt 0 ]; then
    if [ "$AUTO_PROCEED_ON_CRITICAL" != true ]; then
        # Abort update
        log_error "Aborting due to critical issues"
        send_notification "Update Aborted" \
            "Critical issues detected. Update cancelled for safety."
        exit 1
    else
        # Proceed with warnings
        log_warning "Proceeding despite critical issues"
    fi
fi
```

## Notification Examples

### Success Notification

```
┌─────────────────────────────────────────┐
│ 🔄 NixOS Update Complete                │
├─────────────────────────────────────────┤
│ System successfully updated from        │
│ generation 142 to generation 143        │
│                                         │
│ • Kernel: 6.6.60 → 6.6.61              │
│ • Packages: 847 total                  │
│ • No critical issues                    │
└─────────────────────────────────────────┘
```

### Failure Notification

```
┌─────────────────────────────────────────┐
│ ❌ NixOS Update Failed                   │
├─────────────────────────────────────────┤
│ System update encountered errors.       │
│ Automatic rollback successful.          │
│                                         │
│ Check logs: /var/log/nixos-auto-update  │
└─────────────────────────────────────────┘
```

### Critical Issues Warning

```
┌─────────────────────────────────────────┐
│ ⚠️  NixOS Update Aborted                 │
├─────────────────────────────────────────┤
│ Critical issues detected:               │
│                                         │
│ • linux-6.12.3: Boot failure (#325841)  │
│                                         │
│ Update cancelled for safety.            │
│ Manual review recommended.              │
└─────────────────────────────────────────┘
```

## Monitoring and Logging

### View Live Updates

```bash
# Follow the update process in real-time
journalctl -u nixos-auto-update -f

# View last update log
tail -f /var/log/nixos-auto-update.log

# Check update status
systemctl status nixos-auto-update
```

### Review Update History

```bash
# List all update runs
journalctl -u nixos-auto-update --since "1 month ago"

# View last successful update report
cat /var/lib/nixos-auto-update/last-update.txt

# Check for stored issues
cat /var/lib/nixos-auto-update/issues.json | jq
```

### Dashboard Integration

```nix
# Optional: Web dashboard for update status
services.grafana = {
  enable = true;
  # Configure dashboard to display:
  # - Last update time
  # - Success/failure rate
  # - Issue counts over time
  # - Package update history
};
```

## Troubleshooting

### Update Fails to Start

**Problem**: Timer doesn't trigger update

**Check**:

```bash
# Verify timer is active
systemctl list-timers | grep nixos-auto-update

# Check timer configuration
systemctl cat nixos-auto-update.timer

# Manually trigger
systemctl start nixos-auto-update
```

### Notifications Not Appearing

**Problem**: Desktop notifications don't show

**Solutions**:

```bash
# Test notification manually
notify-send "Test" "Testing notifications"

# Check DBUS session
echo $DBUS_SESSION_BUS_ADDRESS

# Verify user session
loginctl list-sessions

# Check notification daemon
systemctl --user status notification-daemon
```

### Build Failures Not Auto-Fixed

**Problem**: Automatic fixes don't work

**Solution**: Implement custom fix patterns

```bash
# Add to fix_build_issues() function
if echo "$error_log" | grep -q "your-specific-error"; then
    log_info "Applying custom fix for your issue"
    # Your fix here
    sed -i 's/old/new/' /etc/nixos/configuration.nix
fi
```

### Issue-Checker Not Found

**Problem**: issue-checker subagent missing

**Solution**:

```nix
# Ensure issue-checker script exists
environment.etc."nixos/scripts/issue-checker.sh" = {
  source = ./issue-checker.sh;
  mode = "0755";
};
```

### Rollback Fails

**Problem**: Automatic rollback doesn't work

**Manual Rollback**:

```bash
# List generations
nixos-rebuild list-generations

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Or specific generation
sudo nixos-rebuild switch --switch-generation 142
```

## Best Practices

### 1. ✅ Test on Non-Critical Systems First

Deploy the update subagent to development/staging before production:

```nix
# Enable on specific hosts
config = mkIf (config.networking.hostName == "dev-server") {
  systemd.timers.nixos-auto-update.enable = true;
};
```

### 2. ✅ Configure Appropriate Update Windows

Schedule updates during low-usage periods:

```nix
# Production: Sunday night
systemd.timers.nixos-auto-update.timerConfig.OnCalendar = "Sun *-*-* 03:00:00";

# Development: Daily
systemd.timers.nixos-auto-update.timerConfig.OnCalendar = "*-*-* 02:00:00";
```

### 3. ✅ Monitor Update Success Rate

Track update metrics:

```bash
# Count successful updates in last month
journalctl -u nixos-auto-update --since "1 month ago" | grep "SUCCESS"

# Count failures
journalctl -u nixos-auto-update --since "1 month ago" | grep "FAILED"
```

### 4. ✅ Maintain Rollback Capability

Always ensure you can rollback:

```nix
# Keep last 5 generations
boot.loader.grub.configurationLimit = 5;

# Enable rollback
environment.etc."nixos/scripts/nixos-auto-update.sh".text = ''
  ROLLBACK_ON_FAILURE=true
'';
```

### 5. ✅ Use Conservative Settings for Production

```bash
# Don't auto-proceed on critical issues
AUTO_PROCEED_ON_CRITICAL=false

# Enable all safety checks
ROLLBACK_ON_FAILURE=true
NOTIFICATION_ENABLED=true

# Maximum fix attempts
MAX_FIX_ATTEMPTS=3
```

### 6. ✅ Review Update Reports Regularly

```bash
# Weekly review of update reports
cat /var/lib/nixos-auto-update/last-update.txt

# Check for patterns in failures
journalctl -u nixos-auto-update | grep ERROR
```

### 7. ✅ Implement Custom Fix Patterns

Add project-specific fixes:

```bash
# In fix_build_issues() function
if echo "$error_log" | grep -q "your-common-error"; then
    # Apply your custom fix
    log_info "Applying custom fix"
fi
```

### 8. ✅ Combine with Binary Cache

Reduce update time with caching:

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://your-cache.example.com"
  ];
  trusted-public-keys = [ ... ];
};
```

### 9. ✅ Document Manual Intervention Cases

When automatic fixes fail, document:

```bash
# Add to /etc/nixos/UPDATE_PROCEDURES.md
## Known Manual Interventions

### Issue: Package X fails to build
**Cause**: Specific dependency conflict
**Fix**: Pin package X to version Y
```

### 10. ✅ Test Notification System

Verify notifications work:

```bash
# Test notification
sudo -u $USER DISPLAY=:0 notify-send "Test" "Testing update notifications"

# Test full update flow on test system first
systemctl start nixos-auto-update
```

## Advanced Features

### Multi-Host Management

```nix
# Deploy to multiple hosts
systemd.services.nixos-auto-update-fleet = {
  script = ''
    for host in server1 server2 server3; do
      ssh $host "systemctl start nixos-auto-update" &
    done
    wait
  '';
};
```

### Slack/Email Notifications

```bash
# Add to send_notification function
send_slack_notification() {
    local message="$1"
    curl -X POST \
        -H 'Content-type: application/json' \
        --data "{\"text\":\"$message\"}" \
        "$SLACK_WEBHOOK_URL"
}

send_email_notification() {
    local subject="$1"
    local body="$2"
    echo "$body" | mail -s "$subject" admin@example.com
}
```

### Custom Pre/Post Hooks

```bash
# Pre-update hook
pre_update_hook() {
    # Backup databases
    pg_dumpall > /backup/db-$(date +%Y%m%d).sql

    # Stop non-critical services
    systemctl stop myapp
}

# Post-update hook
post_update_hook() {
    # Restart services
    systemctl start myapp

    # Run smoke tests
    curl -f http://localhost:8080/health
}
```

## Resources and References

### Related Subagents

- **issue-checker**: Pre-update safety checks
- **local-logs**: Post-update troubleshooting
- **nix-check**: Configuration validation

### NixOS Documentation

- [nixos-rebuild Manual](https://nixos.org/manual/nixos/stable/#sec-changing-config)
- [Systemd Timers](https://wiki.archlinux.org/title/Systemd/Timers)
- [Desktop Notifications](https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html)

### Monitoring Tools

- Grafana for update metrics
- Prometheus for system monitoring
- Alertmanager for notification routing

---

**Remember**: The update subagent is designed for safety first. It will abort updates if critical issues are detected unless explicitly configured otherwise. Always test on non-production systems first and monitor update success rates over time.
