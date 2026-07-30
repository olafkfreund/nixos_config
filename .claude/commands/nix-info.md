# NixOS System Information

Comprehensive system information, status, history, and configuration analysis.

**Replaces Justfile recipes**: `status`, `history`, `info`, `metadata`, `docs`, `help-extended`, `summary`, `analyze-config`

## Quick Usage

**System status**:

```
/nix-info
```

**Full summary**:

```
/nix-info
Full summary
```

**Configuration analysis**:

```
/nix-info
Analyze configuration
```

**Generation history**:

```
/nix-info
Show history
```

## Features

### Information Modes

**Status** (5 seconds - Default):

- ✅ Current system information
- ✅ Active configuration
- ✅ Disk usage
- ✅ Generation count
- ✅ Quick health check

**Full Summary** (15 seconds):

- ✅ Everything in Status
- ✅ All 3 hosts configuration summary
- ✅ Module statistics
- ✅ Package counts
- ✅ Service status
- ✅ Network configuration

**Configuration Analysis** (30 seconds):

- ✅ Detailed configuration breakdown
- ✅ Feature usage analysis
- ✅ Module dependency graph
- ✅ Security posture summary
- ✅ Optimization opportunities

**History** (10 seconds):

- ✅ Generation history
- ✅ Configuration changes
- ✅ Rollback points
- ✅ Deployment timeline

### Specific Information

**Disk Usage**:

```
/nix-info
Disk usage
```

**Package List**:

```
/nix-info
List packages
```

**Service Status**:

```
/nix-info
Service status
```

**Network Info**:

```
/nix-info
Network configuration
```

## Information Workflow

### Daily Check

```bash
# Quick status check
/nix-info

# Review any warnings
```

### Weekly Review

```bash
# Full system summary
/nix-info
Full summary

# Check disk usage trends
```

### Before Deployment

```bash
# Analyze current configuration
/nix-info
Analyze configuration

# Check for optimization opportunities
```

## Output Format

### History Output

```
📜 NixOS Generation History

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current Generation: 142
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Gen  Date                 Description
───────────────────────────────────────────────
142* 2025-12-15 14:23    feat(monitoring): add postgres exporter
141  2025-12-15 09:15    fix(p510): optimize fstrim configuration
140  2025-12-14 16:42    feat(ai): add gemini provider support
139  2025-12-14 11:08    chore: update flake inputs
138  2025-12-13 15:33    security: harden systemd services
137  2025-12-13 10:22    refactor: eliminate mkIf true patterns
136  2025-12-12 14:55    feat(microvm): add development VMs
135  2025-12-11 09:31    docs: add comprehensive patterns guide
134  2025-12-10 16:18    feat(live): add USB installer system
133  2025-12-09 13:45    fix(razer): resolve boot delay issue

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Statistics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Generations:   142
Last 30 Days:        23 deployments
Average per Week:    5.4 deployments
Rollbacks:           2 (last: 2025-12-08)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Recent Changes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Added: postgres-exporter, gemini provider
• Modified: fstrim config, systemd services
• Removed: old monitoring stack (Prometheus/Grafana)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Rollback Points
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current: Generation 142 (2 hours ago)
Safe:    Generation 141 (5 hours ago) ✅
Stable:  Generation 138 (2 days ago) ✅

To rollback: sudo nixos-rebuild switch --rollback
```

## Implementation Details

### Status Command

```bash
# System info
nixos-version
uname -r
uptime

# Configuration info
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Disk usage
df -h /nix/store
du -sh /nix/store

# Health check
systemctl --failed
systemctl list-units --state=running
```

### Full Summary

```bash
# All hosts info
for host in p620 razer p510; do
  nix eval .#nixosConfigurations.$host.config.system.name
  # Count packages, services, etc.
done

# Module statistics
find modules -name "*.nix" | wc -l

# Feature usage analysis
grep -r "enable = true" hosts/*/configuration.nix
```

### Configuration Analysis

```bash
# Lines of code
find . -name "*.nix" -exec wc -l {} + | awk '{s+=$1} END {print s}'

# Dependency analysis
nix-instantiate --eval --strict .#nixosConfigurations.p620.config

# Security analysis
/nix-security
```

### History Command

```bash
# List generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Parse commit messages
git log --oneline -20

# Calculate statistics
```

## Best Practices

### DO ✅

- Check status daily (`/nix-info`)
- Review full summary weekly
- Analyze configuration monthly
- Monitor disk usage trends
- Track generation history

### DON'T ❌

- Ignore warnings in status
- Skip regular health checks
- Let disk fill up (monitor proactively)
- Forget to check history before rollback
- Ignore optimization opportunities

## Troubleshooting

### No Information Displayed

```bash
# Check if Nix is working
nix --version

# Check if configuration is valid
nix flake check

# Try simpler command first
nixos-version
```

### Slow Information Gathering

```bash
# Use quick mode
/nix-info

# Skip analysis for speed
/nix-info
Status
# Just basic info
```

## Integration with Other Commands

### With Cleanup

```bash
# Check before cleanup
/nix-info
Disk usage

# Clean up
/nix-clean

# Check after cleanup
/nix-info
Disk usage
```

### With Deployment

```bash
# Check current state
/nix-info

# Deploy changes
/nix-deploy p620

# Verify deployment
/nix-info
Show history
```

### With Optimization

```bash
# Analyze first
/nix-info
Analyze configuration

# Apply optimizations
/nix-optimize

# Check improvements
/nix-info
```

## Related Commands

- `/nix-clean` - Cleanup based on disk usage info
- `/nix-optimize` - Optimize based on analysis
- `/nix-validate` - Validate configuration
- `/nix-test` - Test configurations
- `/nix-help` - Get help on commands

---

**Pro Tip**: Add `/nix-info` to your shell startup to see system status every time you open a terminal:

```bash
# In ~/.zshrc or ~/.bashrc
/nix-info
```

Stay informed about your NixOS infrastructure! 📊
