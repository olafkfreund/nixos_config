---
context: fork
---

# Config Drift Detective Agent

> **Configuration Drift Detection and Declarative State Enforcement**
> Priority: P2 | Impact: Medium | Effort: Medium

## Overview

The Config Drift Detective agent monitors and detects configuration drift between declared NixOS configurations and actual system state. It ensures systems remain in their intended declarative state and alerts on manual changes or imperative modifications.

## Agent Purpose

**Primary Mission**: Detect and prevent configuration drift by monitoring system state changes, identifying imperative modifications, and ensuring all hosts maintain their declared configuration.

**Trigger Conditions**:

- User mentions drift, state changes, or configuration inconsistencies
- Commands like `/nix-check-drift` or `just check-drift`
- After manual system changes
- Daily drift detection scans (if configured)
- Before critical deployments

## Core Capabilities

### 1. System State Comparison

**What it does**: Compares declared NixOS configuration with actual system state

**Comparison areas**:

```yaml
State Comparison Categories:

1. Package State:
   Declared:
     - firefox (pkgs.firefox)
     - vscode (pkgs.vscode)
     - git (pkgs.git)

   Actual (nix-env):
     - firefox ✅
     - vscode ✅
     - git ✅
     - spotify ⚠️ (not declared, manually installed)

   Drift detected: spotify (imperative install)

2. Service State:
   Declared:
     - prometheus.service: enabled
     - grafana.service: enabled
     - nginx.service: disabled

   Actual (systemctl):
     - prometheus.service: active ✅
     - grafana.service: active ✅
     - nginx.service: active ⚠️ (manually enabled)

   Drift detected: nginx.service (should be disabled)

3. User State:
   Declared:
     - olafkfreund (uid: 1000, groups: wheel, docker)

   Actual (/etc/passwd):
     - olafkfreund (uid: 1000, groups: wheel, docker, video) ⚠️

   Drift detected: Extra group 'video' not declared

4. File State:
   Declared:
     - /etc/nixos → declarative configuration
     - /etc/systemd → managed by NixOS

   Actual:
     - /etc/nixos/local-override.nix ⚠️ (not in git)
     - /etc/systemd/system/custom.service ⚠️ (manual file)

   Drift detected: Untracked configuration files
```

### 2. Imperative Modification Detection

**What it does**: Identifies manual changes made outside declarative configuration

**Detection methods**:

```yaml
Imperative Change Detection:

1. nix-env Usage:
  Command history:
    - nix-env -iA nixpkgs.spotify (2025-01-14 10:23)
    - nix-env -iA nixpkgs.discord (2025-01-13 15:45)

  Issue: Packages installed imperatively
  Impact: Not tracked in configuration
  Fix: Add to user packages in configuration.nix

2. systemctl Modifications:
  Manual changes:
    - systemctl enable nginx.service (2025-01-12 08:30)
    - systemctl mask bluetooth.service (2025-01-10 14:20)

  Issue: Service state changed manually
  Impact: Overridden on next nixos-rebuild
  Fix: Declare in configuration.nix

3. Direct File Edits:
  Modified files:
    - /etc/hosts (2025-01-15 09:15)
    - /etc/resolv.conf (2025-01-14 16:40)

  Issue: System files edited directly
  Impact: Lost on next generation switch
  Fix: Use networking.extraHosts and networking.nameservers

4. User/Group Changes:
  Manual commands:
    - usermod -aG video olafkfreund (2025-01-11 11:30)
    - groupadd developers (2025-01-09 13:45)

  Issue: User/group management outside NixOS
  Impact: Not reproducible
  Fix: Declare in users.users.* configuration
```

### 3. Configuration File Tracking

**What it does**: Monitors configuration file changes and uncommitted modifications

**Tracking includes**:

```yaml
Configuration File Monitoring:

Git Status:
  /home/olafkfreund/.config/nixos/

  Untracked files:
    - hosts/p620/local-override.nix ⚠️
    - modules/temp-fix.nix ⚠️
    - secrets/test-key.age ⚠️

  Modified files:
    - hosts/razer/configuration.nix (uncommitted)
    - modules/features/development.nix (uncommitted)

  Issue: Configuration changes not committed
  Impact: Lost if system rebuilt from git
  Recommendation: Review and commit changes

Local Overrides:
  Detected:
    - /etc/nixos/local-override.nix (not in git)
    - /run/current-system/local-patches/ (custom patches)

  Issue: Local modifications not version controlled
  Impact: Not reproducible on other hosts
  Fix: Integrate into main configuration or document
```

### 4. Generation Comparison

**What it does**: Compares current generation with declared configuration

**Generation analysis**:

```yaml
Generation Drift Analysis:

Current Generation: 246
Last Build: 2025-01-15 10:30:00

Declared Configuration Hash:
  flake.lock: abc123...
  configuration.nix: def456...

Current System Hash:
  /run/current-system: xyz789... ⚠️

Drift detected: System hash doesn't match declared config

Possible causes: 1. Uncommitted changes applied
  2. Manual system modifications
  3. Out-of-sync with git repository

Resolution:
  - Compare current generation with declared config
  - Identify differences
  - Rebuild from clean git state
```

### 5. Service Configuration Drift

**What it does**: Detects changes in service configurations

**Service drift detection**:

```yaml
Service Configuration Drift:

Service: prometheus
  Declared config:
    - retention.time: 30d
    - listen.address: localhost:9090

  Actual config (/etc/systemd/system/prometheus.service):
    - retention.time: 90d ⚠️ (manually modified)
    - listen.address: 0.0.0.0:9090 ⚠️ (security issue!)

  Drift: Configuration modified outside NixOS
  Impact: Reverted on next rebuild
  Fix: Update declared configuration

Service: nginx
  Declared: Disabled
  Actual: Active and enabled ⚠️

  Manual enable detected:
    systemctl enable nginx.service (2025-01-12 08:30)

  Impact: Will be disabled on next rebuild
  Fix: Add services.nginx.enable = true; if needed
```

### 6. Network Configuration Drift

**What it does**: Monitors network settings changes

**Network drift detection**:

```yaml
Network Configuration Drift:

Hostname:
  Declared: p620
  Actual: p620 ✅

DNS Servers:
  Declared: [ "1.1.1.1" "8.8.8.8" ]
  Actual: [ "192.168.1.1" ] ⚠️

  Issue: DNS changed manually (resolv.conf edited)
  Fix: Use networking.nameservers in configuration

Firewall:
  Declared:
    - allowedTCPPorts: [ 22 ]
    - enable: true

  Actual (iptables):
    - Open ports: 22, 80, 443, 3000 ⚠️
    - Status: Active

  Drift: Additional ports opened manually
  Impact: Closed on next rebuild
  Fix: Declare all needed ports in configuration

Tailscale:
  Declared: Enabled with idiot-proof DNS
  Actual: Running but DNS conflicts detected ⚠️

  Issue: Manual DNS configuration interfering
  Fix: Review networking.tailscale configuration
```

### 7. Storage and Mount Drift

**What it does**: Detects filesystem and mount changes

**Storage drift detection**:

```yaml
Filesystem Drift:

Mounts:
  Declared (/etc/fstab via fileSystems):
    - / (ext4, /dev/sda1)
    - /home (ext4, /dev/sda2)
    - /mnt/data (ext4, /dev/sdb1)

  Actual (mount):
    - / (ext4, /dev/sda1) ✅
    - /home (ext4, /dev/sda2) ✅
    - /mnt/data (ext4, /dev/sdb1) ✅
    - /mnt/backup (ext4, /dev/sdc1) ⚠️

  Drift: /mnt/backup not declared
  Impact: Not mounted on reboot
  Fix: Add to fileSystems configuration

NFS Mounts:
  Declared: None
  Actual:
    - /mnt/nas (nfs, server:/share) ⚠️

  Drift: NFS mount added manually
  Fix: Add to fileSystems with fsType = "nfs"
```

### 8. Automated Drift Remediation

**What it does**: Provides automated fixes for detected drift

**Remediation strategies**:

```yaml
Drift Remediation:

1. Auto-Fix (Safe):
  - Remove imperative packages (nix-env -e)
  - Reset service states to declared
  - Remove untracked system files
  - Rebuild from clean configuration

2. Suggest Fix (Review Required):
  - Add manual changes to configuration
  - Update declared state to match actual
  - Document acceptable drift
  - Create override configuration

3. Alert Only (Complex):
  - Major configuration discrepancies
  - Security-sensitive changes
  - Multi-host drift patterns
  - Require manual investigation
```

## Workflow

### Automated Drift Detection

```bash
# Triggered by: /nix-check-drift or daily scans

1. **State Snapshot**
   - Capture current system state
   - Read declared configuration
   - Extract generation metadata
   - Query system services

2. **Comparison Analysis**
   - Compare packages (nix-env vs declared)
   - Compare services (systemctl vs declared)
   - Compare users/groups (actual vs declared)
   - Compare files (tracked vs untracked)
   - Compare network config (actual vs declared)

3. **Drift Detection**
   - Identify discrepancies
   - Categorize drift types
   - Assess severity
   - Determine impact

4. **Root Cause Analysis**
   - Check command history
   - Review system logs
   - Identify manual changes
   - Trace modification sources

5. **Remediation Planning**
   - Generate fix recommendations
   - Classify by safety
   - Estimate impact
   - Prepare rollback plan

6. **Reporting**
   - Create drift report
   - Prioritize issues
   - Suggest fixes
   - Alert stakeholders
```

### Example Drift Report

````markdown
# Configuration Drift Report

Generated: 2025-01-15 19:00:00
Host: p620

## Executive Summary

Drift Detected: Yes (12 issues)
Severity: Medium
Imperative Changes: 5
Untracked Files: 3
Service Drift: 4

Risk Level: MEDIUM
Recommended Action: Review and remediate

## 🔴 CRITICAL Drift (1)

### 1. Security-Sensitive Service Modification

**Service**: nginx
**Declared State**: Disabled
**Actual State**: Active and listening on 0.0.0.0:80 ⚠️

**Details**:

```yaml
Manual Enable:
  Command: systemctl enable nginx.service
  Time: 2025-01-12 08:30:00
  User: root

Security Impact:
  - Exposed HTTP service
  - Not firewall-protected
  - No SSL/TLS configured
  - Listening on all interfaces
```
````

**Risk**: Unauthorized web service exposure
**Priority**: Fix immediately

**Remediation**:

```bash
# Option A: Disable if not needed
systemctl stop nginx.service
systemctl disable nginx.service

# Option B: Declare properly if needed
# Add to configuration.nix:
services.nginx.enable = true;
services.nginx.virtualHosts."example.com" = { ... };
networking.firewall.allowedTCPPorts = [ 80 443 ];
```

## 🟠 HIGH Priority Drift (3)

### 2. Imperative Package Installation

**Packages Installed via nix-env**:

```yaml
- spotify (2025-01-14 10:23)
- discord (2025-01-13 15:45)
- slack (2025-01-11 09:15)
```

**Issue**: Not tracked in declarative configuration
**Impact**: Lost on profile cleanup, not reproducible

**Remediation**:

```nix
# Add to users.users.olafkfreund.packages:
users.users.olafkfreund.packages = with pkgs; [
  spotify
  discord
  slack
];

# Then remove imperative installs:
nix-env -e spotify discord slack
```

### 3. Uncommitted Configuration Changes

**Modified Files**:

```yaml
- hosts/p620/configuration.nix (5 uncommitted changes)
- modules/features/development.nix (2 uncommitted changes)
```

**Uncommitted Changes**:

```diff
# hosts/p620/configuration.nix
+ services.ollama.enable = true;
+ services.ollama.acceleration = "rocm";
+ features.ai-providers.ollama.models = [ "mistral" "llama3.2" ];
```

**Risk**: Lost if rebuilt from git
**Recommendation**: Review and commit

**Remediation**:

```bash
# Review changes
git diff

# Commit if intentional
git add hosts/p620/configuration.nix
git commit -m "feat(p620): enable Ollama with ROCm"
git push

# Or discard if testing
git checkout hosts/p620/configuration.nix
```

## 🟡 MEDIUM Priority Drift (5)

### 4. Extra User Group Membership

**User**: olafkfreund
**Declared Groups**: wheel, docker
**Actual Groups**: wheel, docker, video ⚠️

**Manual Change**:

```bash
usermod -aG video olafkfreund (2025-01-11 11:30)
```

**Remediation**:

```nix
# Add to configuration.nix:
users.users.olafkfreund.extraGroups = [
  "wheel"
  "docker"
  "video"  # Add this
];
```

### 5. Untracked Configuration File

**File**: /etc/nixos/local-override.nix
**Status**: Not in git repository
**Size**: 125 lines

**Contents**:

```nix
# Local testing overrides
{ config, lib, pkgs, ... }:
{
  # Temporary fixes and experiments
  services.test-service.enable = true;
  environment.systemPackages = [ pkgs.test-package ];
}
```

**Risk**: Lost on clean rebuild
**Recommendation**: Review and integrate or delete

**Remediation**:

```bash
# Option A: Integrate into main config
mv /etc/nixos/local-override.nix hosts/p620/testing.nix
git add hosts/p620/testing.nix

# Option B: Delete if no longer needed
rm /etc/nixos/local-override.nix

# Option C: Document as intentional local override
echo "local-override.nix" >> .gitignore
```

## 🟢 LOW Priority Drift (3)

### 6. DNS Configuration Change

**Declared**: [ "1.1.1.1" "8.8.8.8" ]
**Actual**: [ "192.168.1.1" ]

**Manual Edit**: /etc/resolv.conf
**Impact**: Reverted on network restart

**Remediation**:

```nix
# If router DNS is preferred:
networking.nameservers = [ "192.168.1.1" ];

# If Cloudflare DNS is intended:
# No action needed, will fix on rebuild
```

## Drift Summary

**Total Issues**: 12

- CRITICAL: 1 (security exposure)
- HIGH: 3 (imperative changes)
- MEDIUM: 5 (configuration inconsistencies)
- LOW: 3 (minor discrepancies)

**Estimated Fix Time**: 45 minutes
**Rebuild Required**: Yes
**Risk if Unfixed**: Medium (security + reproducibility)

## Recommended Actions

### Immediate (CRITICAL)

1. ✅ Disable nginx or declare properly
2. ✅ Review security implications

### Today (HIGH)

3. ✅ Remove imperative packages, add to config
4. ✅ Commit or discard uncommitted changes
5. ✅ Review untracked configuration files

### This Week (MEDIUM)

6. ⏭️ Add video group to user declaration
7. ⏭️ Clean up local override files
8. ⏭️ Document acceptable drift

### Optional (LOW)

9. ⏭️ Fix DNS configuration
10. ⏭️ Review and update network settings

## Automated Fix Script

```bash
#!/usr/bin/env bash
# Auto-fix safe drift issues

# Remove imperative packages
nix-env -e spotify discord slack

# Disable manually enabled services
systemctl stop nginx.service
systemctl disable nginx.service

# Rebuild from clean configuration
cd /home/olafkfreund/.config/nixos
git checkout hosts/p620/configuration.nix  # Discard uncommitted
nixos-rebuild switch --flake .#p620

echo "Safe drift fixes applied. Review HIGH priority issues manually."
```

## Next Steps

1. ✅ Review this report
2. ⏭️ Fix CRITICAL and HIGH issues
3. ⏭️ Run automated fix script
4. ⏭️ Rebuild system from clean state
5. ⏭️ Verify drift resolution
6. ⏭️ Schedule daily drift scans

---

**Last Drift Scan**: 2025-01-15 19:00:00
**Next Scan**: 2025-01-16 19:00:00 (daily)

````

## Integration with Existing Tools

### With `/nix-fix` Command

```bash
# /nix-fix includes drift detection

/nix-fix                  # Includes drift checks
/nix-fix --drift          # Focus on drift only
/nix-fix --auto-remediate # Auto-fix safe drift
````

### With Deployment Coordinator

```bash
# Pre-deployment drift check
Pre-Deployment:
  - Check for configuration drift
  - Alert if uncommitted changes
  - Warn if imperative modifications

Post-Deployment:
  - Verify drift resolution
  - Confirm system matches declared state
```

### With Security Patrol

```bash
# Security implications of drift
Security Patrol checks:
  - Services enabled manually
  - Firewall changes
  - User/group modifications
  - Exposed network services
```

## Configuration

### Enable Drift Detective

```nix
# modules/gemini-cli/config-drift-detective.nix
{ config, lib, ... }:
{
  options.gemini.drift-detective = {
    enable = lib.mkEnableOption "Configuration drift detection";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Drift detection schedule";
    };

    auto-remediate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically fix safe drift";
    };

    alert-threshold = lib.mkOption {
      type = lib.types.enum [ "low" "medium" "high" "critical" ];
      default = "medium";
      description = "Minimum drift severity to alert";
    };
  };

  config = lib.mkIf config.gemini.drift-detective.enable {
    # Drift detection systemd timer
    systemd.timers.drift-detection = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = config.gemini.drift-detective.schedule;
        Persistent = true;
      };
    };
  };
}
```

## Best Practices

### 1. Regular Drift Scans

```bash
# Daily drift detection
/nix-check-drift

# Before critical deployments
just check-drift
```

### 2. Commit Configuration Changes

```bash
# Always commit changes
git add .
git commit -m "description"
git push

# Don't leave uncommitted changes
```

### 3. Avoid Imperative Commands

```bash
# ❌ Don't use
nix-env -i package
systemctl enable service
usermod -aG group user

# ✅ Use declarative config
# Add to configuration.nix instead
```

## Troubleshooting

### False Drift Detection

**Issue**: Legitimate changes flagged as drift

**Solution**:

```nix
# Document acceptable drift
claude.drift-detective.exceptions = [
  "/etc/local-config"  # Intentional local file
];
```

### High Drift Rate

**Issue**: Continuous drift detected

**Solution**:

```bash
# Identify root cause
/nix-check-drift --verbose

# Review user behavior
# Update workflows to use declarative config
```

## Future Enhancements

1. **Drift Prediction**: Predict drift based on patterns
2. **Auto-Remediation**: More sophisticated auto-fix
3. **Multi-Host Drift**: Compare drift across hosts
4. **Drift Analytics**: Track drift trends over time

## Agent Metadata

```yaml
name: config-drift-detective
version: 1.0.0
priority: P2
impact: medium
effort: medium
dependencies:
  - nix-check agent
  - deployment-coordinator
  - security-patrol
triggers:
  - keyword: drift, state, consistency
  - command: /nix-check-drift
  - schedule: daily
outputs:
  - drift-report.md
  - remediation-script.sh
  - drift-metrics.json
```
