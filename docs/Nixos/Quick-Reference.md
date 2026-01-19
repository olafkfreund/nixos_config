# NixOS Commands - Quick Reference

## Command Cheat Sheet

### Daily Operations

```bash
# Start Claude Code
claude

# Check system health
/system-health-check

# Review open tasks
/check_tasks
```

### Weekly Maintenance

```bash
# Monday: Health check
/system-health-check

# Wednesday: Update flake inputs
/flake-update

# Friday: Review tasks
/check_tasks
```

### Monthly Maintenance

```bash
# Week 1: Configuration audit
/config-audit

# Week 2: Update Claude Code
/update-claude-code

# Week 3: Update other packages
/update-package

# Week 4: Deploy and verify
/deploy-all
```

## Command Syntax

| Command                | Purpose              | Duration | Risk     |
| ---------------------- | -------------------- | -------- | -------- |
| `/flake-update`        | Update flake inputs  | 10-15m   | Med      |
| `/system-health-check` | Infrastructure audit | 5-10m    | None     |
| `/update-claude-code`  | Update Claude Code   | 8-12m    | Low      |
| `/update-package`      | Update any package   | 10-20m   | Med      |
| `/deploy-all`          | Deploy to all hosts  | 5-15m    | Med-High |
| `/config-audit`        | Quality audit        | 15-25m   | None     |

## Common Workflows

### Update and Deploy

```bash
# 1. Health check
/system-health-check

# 2. Update
/flake-update

# 3. Deploy
/deploy-all

# 4. Verify
/system-health-check
```

### Package Update

```bash
# 1. Update package
/update-package

# 2. Review changes
/review

# 3. Deploy
/deploy-all
```

### Quality Maintenance

```bash
# 1. Audit
/config-audit

# 2. Create issues
/new_task

# 3. Verify improvements
/config-audit
```

## Just Commands

### Testing

```bash
just check-syntax     # Syntax validation
just validate-quick   # Quick validation
just quick-test       # Test all hosts (parallel)
just test-host HOST   # Test specific host
```

### Deployment

```bash
just quick-deploy HOST      # Smart deploy (if changed)
just deploy-all-parallel    # Deploy all (parallel)
just p620                   # Deploy to p620
just razer                  # Deploy to razer
just p510                   # Deploy to p510
just samsung                # Deploy to samsung
```

### Monitoring

```bash
grafana-status           # Grafana status
prometheus-status        # Prometheus status
node-exporter-status     # Exporter status
```

## Emergency Procedures

### Fast Rollback

```bash
# Rollback single host
ssh HOST "sudo nixos-rebuild switch --rollback"

# Rollback all hosts
for host in p620 razer p510 samsung; do
  ssh $host "sudo nixos-rebuild switch --rollback"
done
```

### Check System State

```bash
# Service failures
ssh HOST "systemctl --failed"

# Recent logs
ssh HOST "journalctl -xe -n 100"

# Current generation
ssh HOST "readlink /nix/var/nix/profiles/system"
```

### Emergency Deployment

```bash
# Skip tests (use cautiously)
just emergency-deploy HOST
```

## Monitoring Access

### Web Interfaces

```bash
# Grafana
http://p620:3001
# Login: admin / nixos-admin

# Prometheus
http://p620:9090

# Alertmanager
http://p620:9093
```

### CLI Checks

```bash
# Prometheus targets
curl -s http://p620:9090/api/v1/targets | jq

# Active alerts
curl -s http://p620:9093/api/v2/alerts | jq

# Service status
ssh HOST "systemctl status SERVICE"
```

## GitHub Operations

### Issues and Tasks

```bash
# Create new task
/new_task

# Check open tasks
/check_tasks

# Review code
/review
```

### Branches and Commits

```bash
# Branch naming
<type>/<issue-num>-<description>

# Examples:
chore/123-update-claude-code
fix/67-p510-boot-delay
feat/156-new-feature

# Commit format
<type>(<scope>): <description> (#issue)

# Example:
chore(claude-code): update to 2.0.57 (#123)
```

### Pull Requests

```bash
# Create PR
gh pr create --fill

# Merge PR
gh pr merge NUM --squash --delete-branch

# View PR
gh pr view NUM
```

## File Locations

### Commands

```bash
.claude/commands/
├── flake-update.md
├── update-claude-code.md
├── system-health-check.md
├── update-package.md
├── deploy-all.md
└── config-audit.md
```

### Documentation

```bash
docs/Nixos/
├── README.md
├── Command-System-Overview.md
├── Quick-Reference.md
└── [Command guides]
```

### Important Docs

```bash
docs/PATTERNS.md              # Best practices
docs/NIXOS-ANTI-PATTERNS.md   # What to avoid
docs/GITHUB-WORKFLOW.md       # GitHub workflow
.agent-os/product/roadmap.md  # Project roadmap
```

## Host Information

| Host    | Role                   | Hardware          | IP          |
| ------- | ---------------------- | ----------------- | ----------- |
| P620    | Workstation/Monitoring | AMD Ryzen/ROCm    | 192.168.1.x |
| Razer   | Mobile/Development     | Intel/NVIDIA      | 192.168.1.x |
| P510    | Media Server           | Intel Xeon/NVIDIA | 192.168.1.x |
| Samsung | Mobile/Backup          | Intel             | 192.168.1.x |

### Critical Services

**P620 (Monitoring Server):**

- Prometheus (9090)
- Grafana (3001)
- Alertmanager (9093)
- AI Services (Ollama)

**P510 (Media Server):**

- Plex
- NZBGet
- Tautulli

## Troubleshooting

### Build Failures

```bash
# Check syntax
just check-syntax

# Show detailed error
nix build --show-trace

# Keep failed build
nix build --keep-failed
```

### Service Failures

```bash
# Check status
systemctl status SERVICE

# View logs
journalctl -u SERVICE -n 100

# Restart service
systemctl restart SERVICE
```

### Deployment Issues

```bash
# Test configuration
just test-host HOST

# Check differences
just diff HOST

# Rollback
ssh HOST "sudo nixos-rebuild switch --rollback"
```

## Performance Tips

### Fast Testing

```bash
# Parallel testing (75% faster)
just quick-test

# Instead of sequential:
just test-all
```

### Smart Deployment

```bash
# Only deploy if changed
just quick-deploy HOST

# Instead of always deploying:
just HOST
```

### Build Optimization

```bash
# Use binary caches
# Already configured in flake.nix

# Garbage collection
for host in p620 razer p510 samsung; do
  ssh $host "nix-collect-garbage -d"
done
```

## Keyboard Shortcuts

### Claude Code

```bash
# In Claude Code session:
Ctrl+C          # Interrupt current operation
Ctrl+D          # Exit Claude Code
/help           # Show help
/clear          # Clear conversation
```

### Tmux (if using)

```bash
Ctrl+B %        # Split vertically
Ctrl+B "        # Split horizontally
Ctrl+B arrow    # Navigate panes
Ctrl+B d        # Detach session
```

## Safety Checklist

### Before Deployment

- [ ] Configuration tested: `just quick-test`
- [ ] Git status clean: `git status`
- [ ] No critical issues: `/check_tasks`
- [ ] Monitoring operational: `grafana-status`
- [ ] Rollback plan ready

### After Deployment

- [ ] Services running: Check `systemctl --failed`
- [ ] Monitoring updated: Check Grafana dashboards
- [ ] No new alerts: Check Alertmanager
- [ ] Documentation updated
- [ ] GitHub issues closed

## Quick Diagnostics

```bash
# System health
/system-health-check

# Disk usage
for host in p620 razer p510 samsung; do
  ssh $host "df -h / /nix/store"
done

# Service status
for host in p620 razer p510 samsung; do
  ssh $host "systemctl --failed"
done

# Recent errors
for host in p620 razer p510 samsung; do
  ssh $host "journalctl -p err -n 10 --no-pager"
done
```

## Support Resources

### Documentation

- [README](./README.md) - Getting started
- [Overview](./Command-System-Overview.md) - Complete guide
- [Patterns](../PATTERNS.md) - Best practices
- [Anti-patterns](../NIXOS-ANTI-PATTERNS.md) - What to avoid

### Tools

- **Just**: Task runner (`just --list`)
- **GitHub CLI**: `gh --help`
- **Claude Code**: `claude --help`

### Monitoring

- **Grafana**: Visualization and dashboards
- **Prometheus**: Metrics collection
- **Alertmanager**: Alert management

---

**Remember**: When in doubt, check `/system-health-check` first!
