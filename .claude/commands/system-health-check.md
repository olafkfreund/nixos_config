# Comprehensive System Health Check

You are a NixOS infrastructure monitoring specialist. Perform comprehensive health check across all infrastructure components.

## Task Overview

Execute a thorough health assessment of the entire NixOS infrastructure, identifying issues and recommending actions.

## Pre-Check Setup

```bash
# Ensure you have access to all hosts
just ping-hosts

# Check monitoring services are running
grafana-status
prometheus-status
node-exporter-status
```

## Health Check Components

### 1. Host Connectivity Check

```bash
# Test network connectivity to all hosts
ping -c 3 p620.home.freundcloud.com
ping -c 3 razer.home.freundcloud.com
ping -c 3 p510.home.freundcloud.com
ping -c 3 samsung.home.freundcloud.com

# Test SSH connectivity
for host in p620 razer p510 samsung; do
  echo "=== Testing $host ==="
  ssh -o ConnectTimeout=5 $host "hostname && uptime"
done

# Test Tailscale connectivity
tailscale status | grep -E "p620|razer|p510|samsung"
```

**Record:**
- Which hosts are reachable
- Response times
- Any connectivity issues

### 2. System Services Status

```bash
# Check for failed systemd services on each host
echo "=== P620 (Workstation/Monitoring Server) ==="
ssh p620 "systemctl --failed --no-pager"

echo "=== Razer (Mobile/Development) ==="
ssh razer "systemctl --failed --no-pager"

echo "=== P510 (Media Server) ==="
ssh p510 "systemctl --failed --no-pager"

echo "=== Samsung (Mobile/Backup) ==="
ssh samsung "systemctl --failed --no-pager"
```

**For each failed service:**
1. Determine criticality (critical/high/medium/low)
2. Check logs: `journalctl -u SERVICE_NAME -n 50`
3. Determine if action needed

### 3. Critical Services Verification

Check essential services on each host:

**P620 (Monitoring Server):**
```bash
ssh p620 "systemctl is-active prometheus grafana alertmanager node-exporter nixos-exporter systemd-exporter"
```

**P510 (Media Server):**
```bash
ssh p510 "systemctl is-active plex nzbget tautulli node-exporter plex-exporter nzbget-exporter"
```

**Razer & Samsung (Development/Mobile):**
```bash
for host in razer samsung; do
  echo "=== $host ==="
  ssh $host "systemctl is-active node-exporter systemd-exporter"
done
```

**AI Services (P620):**
```bash
ssh p620 "systemctl is-active ollama"
ssh p620 "ai-cli --status"
```

### 4. Disk Usage Analysis

```bash
# Check disk usage on all hosts
for host in p620 razer p510 samsung; do
  echo "=== $host Disk Usage ==="
  ssh $host "df -h / /nix/store /home 2>/dev/null | grep -v tmpfs"
  echo
done

# Check Nix store size and identify cleanup candidates
for host in p620 razer p510 samsung; do
  echo "=== $host Nix Store Analysis ==="
  ssh $host "du -sh /nix/store 2>/dev/null"
  ssh $host "nix-store --gc --print-dead | wc -l | xargs echo 'Dead paths:'"
  echo
done
```

**Disk space warnings:**
- >90% usage: CRITICAL - immediate action required
- >80% usage: WARNING - cleanup recommended
- >70% usage: NOTICE - monitor closely

**Recommended actions if >80%:**
```bash
# Safe cleanup on affected host
ssh HOST "nix-collect-garbage -d"
ssh HOST "nix-store --gc"
ssh HOST "nix-store --optimize"
```

### 5. Memory and CPU Usage

```bash
# Current resource usage
for host in p620 razer p510 samsung; do
  echo "=== $host Resources ==="
  ssh $host "free -h && echo && top -bn1 | head -20"
  echo
done
```

**Check for:**
- High memory usage (>90%)
- High swap usage (>50%)
- High CPU load (>80% sustained)
- Zombie processes

### 6. Boot Time Analysis

```bash
# Check boot times
for host in p620 razer p510 samsung; do
  echo "=== $host Boot Analysis ==="
  ssh $host "systemd-analyze"
  ssh $host "systemd-analyze blame | head -10"
  echo
done
```

**Concerns:**
- Boot time >2 minutes: investigate slow services
- Any service >30 seconds: optimization candidate

### 7. Monitoring Stack Health

```bash
# Prometheus targets status
curl -s http://p620:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# Grafana dashboard count
grafana-status

# Alertmanager status
curl -s http://p620:9093/api/v2/status | jq '.uptime, .cluster.peers[]'

# Check for firing alerts
curl -s http://p620:9093/api/v2/alerts | jq '.[] | select(.status.state == "active")'
```

**Verify:**
- All exporters reporting (should be 4+ per host)
- No gaps in metrics (check Grafana dashboards)
- Alert rules loading correctly
- No firing alerts (unless expected)

### 8. Media Server Health (P510)

```bash
# Plex status
ssh p510 "systemctl status plex"
curl -s http://p510:9104/metrics | grep plex_active_streams

# NZBGet status
ssh p510 "systemctl status nzbget"
curl -s http://p510:9103/metrics | grep nzbget_download_rate

# Tautulli API check
ssh p510 "curl -s 'http://localhost:8181/api/v2?apikey=099a2877fb7c410fb3031e24b3e781bf&cmd=get_server_info' | jq '.response.result'"
```

### 9. Network Stability

```bash
# Tailscale status
ssh p620 "tailscale status"

# DNS resolution check
for host in p620 razer p510 samsung; do
  echo "=== $host DNS ==="
  ssh $host "resolvectl status | grep 'DNS Servers'"
  ssh $host "nslookup google.com | grep Server"
  echo
done

# Check for DNS conflicts (razer common issue)
ssh razer "resolvectl status | grep -A5 'Link.*tailscale'"
```

### 10. Security Audit

```bash
# Check for security updates
for host in p620 razer p510 samsung; do
  echo "=== $host Security ==="
  ssh $host "nixos-rebuild dry-run 2>&1 | grep -i security || echo 'No security updates'"
  echo
done

# Check fail2ban status (if configured)
ssh p620 "systemctl is-active fail2ban && fail2ban-client status"

# Check firewall rules
for host in p620 razer p510 samsung; do
  echo "=== $host Firewall ==="
  ssh $host "iptables -L -n | grep -c 'ACCEPT\\|DROP\\|REJECT' | xargs echo 'Rules:'"
  echo
done
```

### 11. Backup Status

```bash
# Check backup configurations
for host in p620 razer p510 samsung; do
  echo "=== $host Backup Status ==="
  ssh $host "systemctl list-timers | grep backup || echo 'No backup timers configured'"
  echo
done
```

### 12. GitHub Issues Review

```bash
# Check open issues
/check_tasks

# Focus on:
# - Critical priority issues
# - Blocked issues
# - Stale issues (>30 days)
```

## Generate Health Report

Create a comprehensive report with the following sections:

### Executive Summary

```markdown
# Infrastructure Health Report - [DATE]

## Overall Status: [HEALTHY/DEGRADED/CRITICAL]

- Total Hosts: 4
- Hosts Online: X/4
- Critical Issues: X
- Warnings: X
- Open Tasks: X
```

### Host Status Summary

```markdown
## Host Status

| Host | Status | Uptime | Failed Services | Disk Usage | Memory | CPU Load |
|------|--------|--------|----------------|------------|--------|----------|
| P620 | 🟢/🟡/🔴 | Xd | X | X% | X% | X.XX |
| Razer | 🟢/🟡/🔴 | Xd | X | X% | X% | X.XX |
| P510 | 🟢/🟡/🔴 | Xd | X | X% | X% | X.XX |
| Samsung | 🟢/🟡/🔴 | Xd | X | X% | X% | X.XX |

Legend: 🟢 Healthy | 🟡 Warning | 🔴 Critical
```

### Critical Issues

```markdown
## 🔴 Critical Issues (Immediate Action Required)

1. **[Issue Description]**
   - Affected: [Host(s)]
   - Impact: [User impact]
   - Action: [Required action]
   - ETA: [Time to fix]

[Repeat for each critical issue]
```

### Warnings

```markdown
## 🟡 Warnings (Action Recommended)

1. **[Warning Description]**
   - Affected: [Host(s)]
   - Risk: [Potential impact]
   - Recommendation: [Suggested action]
   - Priority: [High/Medium/Low]

[Repeat for each warning]
```

### Monitoring Status

```markdown
## 📊 Monitoring Stack

- **Prometheus:** [Status] - [X targets, Y series]
- **Grafana:** [Status] - [X dashboards]
- **Alertmanager:** [Status] - [X alerts firing]
- **Exporters:** [X/Y reporting]

### Firing Alerts

[List any active alerts]

### Missing Metrics

[List any hosts/services not reporting]
```

### Service Health

```markdown
## 🛠️ Service Health

### P620 (Monitoring Server)
- Prometheus: [Status]
- Grafana: [Status]
- AI Services: [Status]
- [List failed services]

### P510 (Media Server)
- Plex: [Status] - [X active streams]
- NZBGet: [Status] - [X active downloads]
- [List failed services]

### Razer/Samsung (Mobile)
- Node Exporter: [Status]
- [List failed services]
```

### Resource Utilization

```markdown
## 💾 Resource Utilization

### Disk Usage
- P620: [X%] - [Action: none/cleanup/urgent]
- Razer: [X%] - [Action: none/cleanup/urgent]
- P510: [X%] - [Action: none/cleanup/urgent]
- Samsung: [X%] - [Action: none/cleanup/urgent]

### Memory Usage
- P620: [X%] - [Swap: X%]
- Razer: [X%] - [Swap: X%]
- P510: [X%] - [Swap: X%]
- Samsung: [X%] - [Swap: X%]

### Nix Store
- Total size: [X GB]
- Dead paths: [X]
- Cleanup potential: [X GB]
```

### Recommendations

```markdown
## 💡 Recommendations

### Immediate Actions
1. [Action 1]
2. [Action 2]

### Short-term (This Week)
1. [Action 1]
2. [Action 2]

### Long-term (This Month)
1. [Action 1]
2. [Action 2]

### Preventive Measures
1. [Measure 1]
2. [Measure 2]
```

### Open Issues Summary

```markdown
## 📋 Open GitHub Issues

- Total: X
- Critical: X
- High Priority: X
- Blocked: X
- Stale (>30 days): X

### Top Priority Issues
1. #X - [Issue title] - [Priority]
2. #X - [Issue title] - [Priority]
```

## Action Items

Generate prioritized action items:

### 🔴 CRITICAL (Do Now)

- [ ] [Action item with specific command]
- [ ] [Action item with specific command]

### 🟡 HIGH (Do Today)

- [ ] [Action item with specific command]
- [ ] [Action item with specific command]

### 🟢 MEDIUM (Do This Week)

- [ ] [Action item with specific command]
- [ ] [Action item with specific command]

### ⚪ LOW (Monitor)

- [ ] [Action item with specific command]
- [ ] [Action item with specific command]

## Success Criteria

- [ ] All hosts connectivity verified
- [ ] Failed services identified and categorized
- [ ] Disk usage checked and cleanup performed if needed
- [ ] Monitoring stack verified operational
- [ ] Critical services confirmed running
- [ ] Resource utilization analyzed
- [ ] Security status reviewed
- [ ] Comprehensive report generated
- [ ] Action items prioritized
- [ ] Recommendations documented

## Follow-up Actions

```bash
# Schedule next health check
echo "$(date -d '+7 days' '+%Y-%m-%d'): Run /system-health-check" >> docs/scheduled-tasks.txt

# Create issues for critical items
/new_task  # For each critical issue identified

# Update monitoring if gaps found
# Edit modules/services/monitoring.nix
```

## Documentation

Save the health report to:

```bash
# Create report file
vim docs/health-reports/health-report-$(date +%Y-%m-%d).md

# Link to latest
ln -sf health-report-$(date +%Y-%m-%d).md docs/health-reports/latest.md
```

## Notes

- Run health checks weekly (or after major changes)
- Compare trends with previous reports
- Update monitoring alerts based on findings
- Document any recurring issues
- Track action item completion rates

## Example Output

```markdown
# Infrastructure Health Report - 2025-01-29

## Overall Status: HEALTHY ✅

- Total Hosts: 4/4 online
- Critical Issues: 0
- Warnings: 2
- Open Tasks: 5

## Summary
All systems operational. Minor cleanup recommended on P510 (disk 78%).
Monitoring stack fully functional. No critical alerts.

## Action Items
- [ ] Run cleanup on P510 (disk usage high)
- [ ] Investigate razer DNS intermittent issues
- [ ] Update 3 packages with security fixes
```
