# AI Infrastructure Troubleshooting Guide

## Table of Contents

1. [Common Issues](#common-issues)
2. [AI Provider Problems](#ai-provider-problems)
3. [Monitoring and Metrics](#monitoring-and-metrics)
4. [Performance Issues](#performance-issues)
5. [Security Problems](#security-problems)
6. [Network Issues](#network-issues)
7. [Storage and Disk Issues](#storage-and-disk-issues)
8. [Service Management](#service-management)
9. [Diagnostic Commands](#diagnostic-commands)
10. [Recovery Procedures](#recovery-procedures)

## Common Issues

### AI Command Not Found

**Symptom**: `ai-cli: command not found`
**Diagnosis**:

```bash
which ai-cli
echo $PATH
systemctl status ai-providers
```

**Resolution**:

1. Check if AI providers are enabled in configuration
2. Rebuild and deploy system: `just deploy`
3. Source shell configuration: `source ~/.zshrc`
4. Check package installation: `nix-env -q | grep -i ai`

### AI Providers Not Responding

**Symptom**: AI commands hang or timeout
**Diagnosis**:

```bash
ai-cli --status
systemctl status ai-provider-optimization
journalctl -u ai-provider-optimization --since "1 hour ago"
curl -I https://api.anthropic.com
```

**Resolution**:

1. Check internet connectivity
2. Verify API keys: `./scripts/manage-secrets.sh status`
3. Restart provider optimization: `systemctl restart ai-provider-optimization`
4. Test individual providers: `ai-cli -p anthropic "test"`

### High System Load

**Symptom**: System becomes unresponsive
**Diagnosis**:

```bash
top
htop
uptime
systemctl status ai-*
ps aux | grep -E "(ai-|ollama)" | head -20
```

**Resolution**:

1. Stop load testing: `ai-load-test stop`
2. Restart system optimization: `systemctl restart ai-system-optimization`
3. Check for runaway processes: `pkill -f "ai-load-test"`
4. Monitor resources: `iostat -x 1 5`

## AI Provider Problems

### Anthropic Claude Issues

**Common Problems**:

- API key expired or invalid
- Rate limiting
- Network connectivity issues

**Diagnostics**:

```bash
# Check API key
ls -la /run/agenix/api-anthropic
curl -H "Authorization: Bearer $(cat /run/agenix/api-anthropic)" https://api.anthropic.com/v1/messages

# Test connectivity
ai-cli -p anthropic -v "test connection"
```

**Resolution**:

1. Verify API key: `./scripts/manage-secrets.sh edit api-anthropic`
2. Check rate limits in logs
3. Test with different model: `ai-cli -p anthropic -m claude-3-haiku "test"`

### OpenAI Issues

**Common Problems**:

- API key issues
- Model availability
- Quota exceeded

**Diagnostics**:

```bash
# Test API key
curl -H "Authorization: Bearer $(cat /run/agenix/api-openai)" https://api.openai.com/v1/models

# Check usage
ai-cli -p openai --list-models
```

**Resolution**:

1. Update API key if needed
2. Check OpenAI status page
3. Verify account quota and billing

### Ollama Local Issues

**Common Problems**:

- Service not running
- Model not loaded
- GPU acceleration issues

**Diagnostics**:

```bash
# Check service status
systemctl status ollama
curl http://localhost:11434/api/tags

# Check GPU
rocm-smi  # For AMD GPU on P620
nvidia-smi  # For NVIDIA GPU on other hosts

# Check models
ollama list
```

**Resolution**:

1. Restart Ollama: `systemctl restart ollama`
2. Pull models: `ollama pull mistral-small3.1`
3. Check GPU access: `ls -la /dev/dri/`
4. Verify ROCm installation (P620): `rocm-smi`

### Gemini Issues

**Common Problems**:

- API key configuration
- Service quotas
- Regional availability

**Diagnostics**:

```bash
# Test API key
ai-cli -p gemini -v "test connection"

# Check configuration
cat /etc/ai-providers.json | jq '.providers.gemini'
```

**Resolution**:

1. Verify API key: `./scripts/manage-secrets.sh edit api-gemini`
2. Check Google Cloud Console for quotas
3. Test with different regions

## Monitoring and Metrics

### Grafana Dashboard Issues

**Symptom**: Dashboards not loading or showing "No data"
**Diagnosis**:

```bash
systemctl status grafana
curl -f http://localhost:3001/api/health
ls -la /var/lib/grafana/dashboards/
grafana-status
```

**Resolution**:

1. Restart Grafana: `systemctl restart grafana`
2. Check dashboard files: `ai-dashboard-status`
3. Reload dashboards: `ai-dashboard-reload`
4. Verify data source configuration
5. Check permissions: `chown -R grafana:grafana /var/lib/grafana/`

### Prometheus Not Scraping

**Symptom**: Missing metrics in Prometheus
**Diagnosis**:

```bash
curl -s http://localhost:9090/api/v1/targets
systemctl status prometheus
prometheus-status
```

**Resolution**:

1. Check target configuration: `cat /etc/prometheus/prometheus.yml`
2. Restart Prometheus: `systemctl restart prometheus`
3. Verify network connectivity to targets
4. Check firewall rules: `firewall-cmd --list-ports`

### Node Exporter Issues

**Symptom**: Host metrics missing
**Diagnosis**:

```bash
systemctl status node-exporter
curl http://localhost:9100/metrics
node-exporter-status
```

**Resolution**:

1. Restart node exporter: `systemctl restart node-exporter`
2. Check port availability: `netstat -tlnp | grep 9100`
3. Verify service configuration

### Custom Exporters Failing

**Symptom**: NixOS or systemd metrics missing
**Diagnosis**:

```bash
systemctl status nixos-exporter systemd-exporter
curl http://localhost:9101/metrics  # NixOS metrics
curl http://localhost:9102/metrics  # Systemd metrics
```

**Resolution**:

1. Check Python HTTP servers: `ps aux | grep python`
2. Restart exporters: `systemctl restart nixos-exporter systemd-exporter`
3. Check script permissions and dependencies

## Performance Issues

### Slow AI Response Times

**Symptom**: AI commands taking >10 seconds
**Diagnosis**:

```bash
time ai-cli "test performance"
ai-load-test light
systemctl status ai-performance-monitor
```

**Resolution**:

1. Check system resources: `htop`, `free -h`
2. Restart performance optimization: `systemctl restart ai-system-optimization`
3. Clear cache: `rm -rf /var/cache/ai-analysis/*`
4. Run performance analysis: `systemctl start ai-performance-monitor`

### High Memory Usage

**Symptom**: System running out of memory
**Diagnosis**:

```bash
free -h
ps aux --sort=-%mem | head -20
systemctl status ai-memory-optimization
```

**Resolution**:

1. Run memory optimization: `systemctl start ai-memory-optimization`
2. Restart high-memory services: `systemctl restart ollama grafana`
3. Clear page cache: `echo 1 > /proc/sys/vm/drop_caches`
4. Check for memory leaks: `valgrind --tool=memcheck ai-cli "test"`

### CPU Overload

**Symptom**: High CPU usage sustained
**Diagnosis**:

```bash
top -o %CPU
htop
iostat -x 1 5
systemctl status ai-system-optimization
```

**Resolution**:

1. Stop load testing: `ai-load-test stop`
2. Restart system optimization: `systemctl restart ai-system-optimization`
3. Check for runaway processes: `pkill -f "ai-load-test"`
4. Adjust CPU governor: `echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`

## Security Problems

### SSH Login Failures

**Symptom**: Cannot connect via SSH
**Diagnosis**:

```bash
ssh-security-check
systemctl status sshd
journalctl -u sshd --since "1 hour ago"
```

**Resolution**:

1. Check SSH service: `systemctl status sshd`
2. Verify SSH configuration: `sshd -t`
3. Check fail2ban status: `fail2ban-client status ssh`
4. Review firewall rules: `iptables -L INPUT -n`

### Fail2ban Issues

**Symptom**: Legitimate users getting banned
**Diagnosis**:

```bash
fail2ban-client status ssh
fail2ban-client get ssh banip
journalctl -u fail2ban --since "1 hour ago"
```

**Resolution**:

1. Unban IP: `fail2ban-client set ssh unbanip IP_ADDRESS`
2. Check fail2ban configuration: `cat /etc/fail2ban/jail.conf`
3. Adjust ban thresholds if needed
4. Restart fail2ban: `systemctl restart fail2ban`

### Security Audit Failures

**Symptom**: Security audit reports issues
**Diagnosis**:

```bash
systemctl status ai-security-audit
journalctl -u ai-security-audit --since "1 day ago"
cat /var/log/ssh-security-audit.log
```

**Resolution**:

1. Review audit findings
2. Fix identified vulnerabilities
3. Update security configurations
4. Restart security services: `systemctl restart ai-security-audit`

## Network Issues

### Monitoring Server Unreachable

**Symptom**: Cannot reach DEX5550 monitoring server
**Diagnosis**:

```bash
ping dex5550.home.freundcloud.com
telnet dex5550.home.freundcloud.com 3001
systemctl status networking
```

**Resolution**:

1. Check network connectivity: `ping 8.8.8.8`
2. Verify DNS resolution: `nslookup dex5550.home.freundcloud.com`
3. Check firewall on monitoring server
4. Restart networking: `systemctl restart networking`

### Prometheus Targets Down

**Symptom**: Metrics not being collected
**Diagnosis**:

```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'
systemctl status node-exporter
```

**Resolution**:

1. Check target services: `systemctl status node-exporter`
2. Verify network connectivity between hosts
3. Check firewall rules on target hosts
4. Restart Prometheus: `systemctl restart prometheus`

## Storage and Disk Issues

### Disk Space Critical (P510)

**Symptom**: Disk usage >85% (P510 currently at 79.6%)
**Diagnosis**:

```bash
df -h
du -sh /nix/store /var/log /var/lib
systemctl status ai-storage-analysis
```

**Resolution**:

1. Run emergency cleanup: `systemctl start ai-emergency-storage-cleanup`
2. Clean Nix store: `nix-store --optimise && nix-collect-garbage -d`
3. Clean logs: `journalctl --vacuum-time=7d`
4. Clean Docker: `docker system prune -af`

### Nix Store Issues

**Symptom**: Nix operations failing
**Diagnosis**:

```bash
nix-store --verify --check-contents
df -h /nix/store
du -sh /nix/store
```

**Resolution**:

1. Optimize store: `nix-store --optimise`
2. Garbage collection: `nix-collect-garbage -d`
3. Verify store integrity: `nix-store --verify --repair`
4. Check for corruption: `nix-store --verify --check-contents`

## Service Management

### Systemd Service Failures

**Symptom**: AI services not starting
**Diagnosis**:

```bash
systemctl --failed
systemctl status ai-*
journalctl -u SERVICE_NAME --since "1 hour ago"
```

**Resolution**:

1. Check service configuration: `systemctl cat SERVICE_NAME`
2. Review logs: `journalctl -u SERVICE_NAME -f`
3. Restart service: `systemctl restart SERVICE_NAME`
4. Check dependencies: `systemctl list-dependencies SERVICE_NAME`

### Timer Issues

**Symptom**: Scheduled tasks not running
**Diagnosis**:

```bash
systemctl list-timers
systemctl status ai-*.timer
journalctl -u TIMER_NAME --since "1 day ago"
```

**Resolution**:

1. Check timer configuration: `systemctl cat TIMER_NAME`
2. Start timer: `systemctl start TIMER_NAME`
3. Enable timer: `systemctl enable TIMER_NAME`
4. Check system time: `timedatectl status`

## Diagnostic Commands

### System Health Check

```bash
#!/bin/bash
# Quick system health check script

echo "=== System Health Check ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo

echo "=== System Resources ==="
free -h
df -h | grep -E "(/$|/mnt)"
echo

echo "=== AI Services Status ==="
systemctl status ai-* --no-pager | grep -E "(Active|Main PID|Tasks)"
echo

echo "=== AI Provider Status ==="
if command -v ai-cli &>/dev/null; then
    ai-cli --status
else
    echo "ai-cli not available"
fi
echo

echo "=== Monitoring Services ==="
systemctl status grafana prometheus --no-pager | grep -E "(Active|Main PID)"
echo

echo "=== Recent Errors ==="
journalctl -p err --since "1 hour ago" --no-pager | tail -10
echo

echo "=== Load Average ==="
cat /proc/loadavg
echo

echo "=== Network Connectivity ==="
ping -c 3 8.8.8.8 | grep -E "(transmitted|received)"
echo

echo "=== Storage Usage ==="
du -sh /nix/store /var/log /var/lib 2>/dev/null
echo

echo "=== Recent AI Activity ==="
journalctl -u ai-* --since "1 hour ago" --no-pager | tail -5
```

### Performance Diagnostics

```bash
#!/bin/bash
# Performance diagnostic script

echo "=== Performance Diagnostics ==="
echo "Date: $(date)"
echo

echo "=== CPU Information ==="
lscpu | grep -E "(Model name|CPU\(s\)|Thread|Core)"
echo

echo "=== Memory Information ==="
free -h
cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached)"
echo

echo "=== Disk I/O ==="
iostat -x 1 3
echo

echo "=== Network Statistics ==="
ss -tuln | grep -E "(State|LISTEN)" | head -10
echo

echo "=== Load Testing Results ==="
if [ -f "/var/lib/ai-analysis/load-test-reports/load_test_$(hostname)_*.json" ]; then
    latest_report=$(ls -t /var/lib/ai-analysis/load-test-reports/load_test_$(hostname)_*.json | head -1)
    echo "Latest load test: $(basename "$latest_report")"
    jq -r '.load_test_summary' "$latest_report" 2>/dev/null || echo "Could not parse report"
else
    echo "No load test reports found"
fi
echo

echo "=== AI Provider Response Times ==="
for provider in anthropic ollama; do
    echo "Testing $provider..."
    time timeout 10 ai-cli -p "$provider" "test" &>/dev/null && echo "$provider: OK" || echo "$provider: FAILED"
done
```

## Recovery Procedures

### Emergency System Recovery

```bash
#!/bin/bash
# Emergency recovery script

echo "=== Emergency Recovery Procedure ==="
echo "Date: $(date)"
echo

# Stop non-essential services
echo "Stopping non-essential services..."
systemctl stop ai-continuous-load-test
systemctl stop ai-load-test-profiles
systemctl stop ai-system-validation

# Restart core services
echo "Restarting core services..."
systemctl restart ai-provider-optimization
systemctl restart ai-analysis
systemctl restart ai-performance-monitor

# Check system resources
echo "Checking system resources..."
free -h
df -h

# Clean up if needed
echo "Cleaning up temporary files..."
rm -rf /tmp/ai-*
rm -rf /var/cache/ai-analysis/*

# Run quick validation
echo "Running quick validation..."
systemctl start ai-quick-validation

echo "Recovery procedure completed"
echo "Check logs: journalctl -u ai-* --since '5 minutes ago'"
```

### Service Reset Procedure

```bash
#!/bin/bash
# Service reset procedure

echo "=== Service Reset Procedure ==="
echo "Date: $(date)"
echo

# Stop all AI services
echo "Stopping all AI services..."
systemctl stop ai-*

# Clear caches and temporary files
echo "Clearing caches..."
rm -rf /var/cache/ai-analysis/*
rm -rf /tmp/ai-*

# Restart services in order
echo "Restarting services in order..."
systemctl start ai-provider-optimization
sleep 5
systemctl start ai-analysis
sleep 5
systemctl start ai-performance-monitor
sleep 5
systemctl start ai-memory-optimization

# Test functionality
echo "Testing functionality..."
if command -v ai-cli &>/dev/null; then
    ai-cli --status
else
    echo "ai-cli not available"
fi

echo "Service reset completed"
```

---

_This troubleshooting guide should be used in conjunction with the main Operations Runbook._
_For additional help, check system logs and monitoring dashboards._
_Last Updated: $(date)_
