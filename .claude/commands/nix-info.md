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

### Status Output

```
🖥️  NixOS System Information

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
System
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Host:           p620
System:         x86_64-linux
NixOS:          25.11.20251215.c9b6fb7 (Warbler)
Kernel:         6.18.0
Uptime:         3 days, 14:23:45

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Generation:     142 (current)
Previous:       141 (rollback available)
Total:          142 generations
Age:            2 hours

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Storage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Store Size:     75.2 GB
Available:      54.3 GB (42%)
Root Usage:     127.5 GB / 250 GB (51%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Health Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ System healthy
✅ All services running
✅ No failed units
⚠️  Disk usage moderate (consider cleanup)
✅ Network connectivity good

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Quick Actions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Run /nix-clean for disk cleanup
• Run /nix-info Full summary for details
• Run /nix-help for available commands
```

### Full Summary Output

```
🖥️  NixOS Infrastructure Summary

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Infrastructure Overview
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active Hosts:   3 (P620, Razer, P510)
Total Modules:  141 feature modules
Template Type:  95% code deduplication
NixOS Version:  25.11 (Warbler)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Host Configuration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

P620 (AMD Workstation):
  Template:     workstation
  Packages:     1,247
  Services:     34 active
  Features:     Development, Desktop, AI, Monitoring
  Status:       ✅ Healthy

Razer (Intel/NVIDIA Laptop):
  Template:     laptop
  Packages:     892
  Services:     28 active
  Features:     Development, Desktop, Mobile
  Status:       ✅ Healthy

P510 (Intel Xeon Server):
  Template:     server
  Packages:     456
  Services:     18 active
  Features:     Media Server, Headless
  Status:       ✅ Healthy

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Module Statistics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Modules:       141
Service Modules:     47
Feature Modules:     52
Hardware Modules:    18
Desktop Modules:     24

Most Used Features:
  1. development       (3 hosts)
  2. desktop           (3 hosts)
  3. networking        (3 hosts)
  4. security          (3 hosts)
  5. ai-providers      (2 hosts)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Storage Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Store Size:    287 GB (all hosts)
Avg per Host:        71.75 GB
Largest Host:        P620 (92 GB)

Generations:
  P620:     142 generations (oldest: 45 days)
  Razer:    98 generations (oldest: 32 days)
  P510:     87 generations (oldest: 28 days)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Recommendations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• P620: Run /nix-clean (45 days of generations)
• All: Consider running /nix-optimize monthly
• Network: All hosts connected via Tailscale ✅
```

### Configuration Analysis Output

```
🔍 NixOS Configuration Analysis

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Configuration Breakdown
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Lines:         14,237
Configuration:       3,421 lines
Modules:            8,916 lines
Templates:          1,234 lines
Documentation:        666 lines

Code Deduplication:  95% (via templates)
Module Reuse:        87% (shared across hosts)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Feature Usage Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Development Features:
  ✅ Languages: Python, Go, Rust, Node.js (3 hosts)
  ✅ Editors: VS Code, Neovim, Emacs (3 hosts)
  ✅ Tools: Git, Docker, Kubernetes (3 hosts)

Desktop Features:
  ✅ Hyprland: 2 hosts (P620, Razer)
  ✅ Plasma: 1 host (fallback on P620)
  ✅ Themes: Stylix unified theming

System Features:
  ✅ Virtualization: Docker (3), MicroVM (1)
  ✅ Monitoring: Removed (native tools used)
  ✅ AI Providers: 4 providers, 6 models

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Security Posture
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Overall Score:       91/100 (Excellent)

Service Hardening:   ✅ 100% DynamicUser coverage
Secret Management:   ✅ Runtime loading only (agenix)
Firewall:           ✅ Enabled, minimal ports
SSH:                ✅ Key-only, no root login
Network:            ✅ Tailscale VPN mesh

Anti-Patterns:       ✅ Zero detected
Best Practices:      ✅ All followed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Module Dependencies
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Core Modules:        23 (always loaded)
Conditional:         118 (feature-flagged)
Circular Deps:       0 (none detected) ✅
Missing Deps:        0 (all resolved) ✅

Dependency Depth:
  Max:               4 levels
  Average:           2.3 levels
  Complex Modules:   monitoring (4), ai-providers (3)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Optimization Opportunities
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Disk Cleanup:
   • P620: Remove 15 old generations → Save ~12 GB
   • All: Run store optimization → Save ~25 GB

2. Build Performance:
   • Enable more binary caches
   • Current cache hit rate: 87%

3. Module Loading:
   • Consider lazy evaluation for heavy modules
   • Current evaluation time: 2.3s (good)

4. Security:
   • All checks passed ✅
   • No improvements needed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Suggested Actions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Run /nix-clean for disk cleanup
• Run /nix-optimize for performance tuning
• Configuration is in excellent shape! ✅
```

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
# Default mode is fast

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
