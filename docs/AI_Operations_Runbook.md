# AI Infrastructure Operations Runbook

## Overview

This runbook provides comprehensive operational procedures for managing the AI infrastructure deployed across the NixOS environment. It covers monitoring, troubleshooting, maintenance, and emergency procedures.

## Quick Reference

### Key Commands

```bash
# AI Provider Management
ai-cli "test query"                    # Test AI provider
ai-cli --status                        # Check provider status
ai-switch anthropic                    # Switch default provider

# Load Testing
ai-load-test moderate                  # Run moderate load test
ai-load-test-status                    # Check load test status
ai-load-test-report                    # View latest test report

# Performance Monitoring
ai-dashboard-status                    # Check dashboard status
ai-dashboard-reload                    # Reload dashboards
grafana-status                         # Check Grafana status
prometheus-status                      # Check Prometheus status

# System Validation
systemctl start ai-system-validation  # Run system validation
systemctl start ai-quick-validation   # Run quick validation

# Security Monitoring
ssh-security-check                     # Check SSH security status
systemctl status fail2ban             # Check fail2ban status
```

### Service Endpoints

- **Grafana**: <http://dex5550.home.freundcloud.com:3001> (admin/nixos-admin)
- **Prometheus**: <http://dex5550.home.freundcloud.com:9090>
- **Alertmanager**: <http://dex5550.home.freundcloud.com:9093>
- **Ollama**: <http://localhost:11434> (P620 only)

## Daily Operations

### Morning Health Check

```bash
# 1. Check overall system health
systemctl status ai-*

# 2. Check AI provider status
ai-cli --status

# 3. Check monitoring services
grafana-status
prometheus-status

# 4. Check recent alerts
journalctl -u ai-* --since "24 hours ago" | grep -i "error\|critical\|warning"

# 5. Check disk usage on critical hosts
df -h | grep -E "(/$|/mnt)" | awk '$5 > 70 { print $0 }'
```

### Weekly Maintenance

```bash
# 1. Run comprehensive system validation
systemctl start ai-system-validation

# 2. Run load testing
ai-load-test moderate

# 3. Check SSH security
ssh-security-check

# 4. Clean up old logs and reports
find /var/log/ai-analysis -name "*.log" -mtime +30 -delete
find /var/lib/ai-analysis -name "*report*" -mtime +30 -delete

# 5. Update AI provider configurations
systemctl restart ai-provider-optimization
```

## Host-Specific Operations

### P620 (AMD Workstation - Monitoring Client)

```bash
# Primary AI development and testing host
# Status: Monitoring client sending data to DEX5550

# Check AMD GPU status
rocm-smi

# Monitor AI service resource usage
htop -p $(pgrep -f "ai-|ollama")

# Check Ollama service
systemctl status ollama
ollama list

# Test AI providers
ai-cli -p anthropic "test P620 functionality"
ai-cli -p ollama "test local inference"
```

### DEX5550 (Intel SFF - Monitoring Server)

```bash
# Primary monitoring server
# Status: Centralized monitoring for all hosts

# Check monitoring services
systemctl status prometheus grafana alertmanager

# Check metrics collection
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'

# View active alerts
curl -s http://localhost:9093/api/v1/alerts

# Check dashboard provisioning
ls -la /var/lib/grafana/dashboards/
```

### P510 (Intel Xeon - High Storage Usage)

```bash
# Critical storage monitoring required
# Status: 79.6% disk usage - requires attention

# Check disk usage
df -h /
du -sh /nix/store
du -sh /var/log

# Emergency cleanup if needed
nix-collect-garbage -d
systemctl start ai-emergency-storage-cleanup

# Monitor storage trends
systemctl status ai-storage-analysis
```

### Razer (Intel/NVIDIA Laptop)

```bash
# Mobile development platform
# Status: Monitoring client with hybrid graphics

# Check NVIDIA GPU status
nvidia-smi

# Check power management
powertop

# Verify network connectivity to monitoring server
ping dex5550.home.freundcloud.com
```

## Troubleshooting

### AI Provider Issues

#### Symptom: AI commands returning "No providers available"

```bash
# Diagnosis
ai-cli --status
systemctl status ai-provider-optimization
ls -la /run/agenix/api-*

# Resolution
1. Check API keys: ./scripts/manage-secrets.sh status
2. Restart provider optimization: systemctl restart ai-provider-optimization
3. Test individual providers: ai-cli -p anthropic "test"
4. Check network connectivity: curl -I https://api.anthropic.com
```

#### Symptom: High AI response times

```bash
# Diagnosis
ai-load-test light
systemctl status ai-performance-monitor
journalctl -u ai-provider-optimization --since "1 hour ago"

# Resolution
1. Check system resources: htop, free -h
2. Restart performance optimization: systemctl restart ai-system-optimization
3. Clear AI cache: rm -rf /var/cache/ai-analysis/*
4. Check network latency: ping api.anthropic.com
```

### Monitoring Issues

#### Symptom: Grafana dashboards not loading

```bash
# Diagnosis
systemctl status grafana
curl -f http://localhost:3001/api/health
ls -la /var/lib/grafana/dashboards/

# Resolution
1. Restart Grafana: systemctl restart grafana
2. Check dashboard files: ai-dashboard-status
3. Reload dashboards: ai-dashboard-reload
4. Check permissions: chown -R grafana:grafana /var/lib/grafana/
```

#### Symptom: Missing metrics in Prometheus

```bash
# Diagnosis
curl -s http://localhost:9090/api/v1/targets
systemctl status node-exporter
systemctl status nixos-exporter

# Resolution
1. Restart exporters: systemctl restart node-exporter nixos-exporter
2. Check firewall: firewall-cmd --list-ports
3. Verify scrape configs: cat /etc/prometheus/prometheus.yml
4. Check network connectivity between hosts
```

### Performance Issues

#### Symptom: High CPU usage on AI services

```bash
# Diagnosis
top -p $(pgrep -f "ai-|ollama")
systemctl status ai-performance-monitor
journalctl -u ai-system-optimization --since "1 hour ago"

# Resolution
1. Check load test results: ai-load-test-report
2. Restart resource optimization: systemctl restart ai-system-optimization
3. Scale down concurrent operations: ai-load-test light
4. Check for memory leaks: valgrind --tool=memcheck ai-cli "test"
```

#### Symptom: Storage space critical

```bash
# Diagnosis
df -h
du -sh /nix/store /var/log /var/lib
systemctl status ai-storage-analysis

# Resolution
1. Run emergency cleanup: systemctl start ai-emergency-storage-cleanup
2. Clean Nix store: nix-store --optimise && nix-collect-garbage -d
3. Clean Docker (if applicable): docker system prune -af
4. Rotate logs: journalctl --vacuum-time=7d
```

### Security Issues

#### Symptom: Multiple failed SSH attempts

```bash
# Diagnosis
ssh-security-check
fail2ban-client status ssh
journalctl -u sshd --since "1 hour ago" | grep "Failed password"

# Resolution
1. Check banned IPs: fail2ban-client status ssh
2. Review SSH logs: journalctl -u sshd --since "24 hours ago"
3. Update SSH configuration if needed
4. Check firewall rules: iptables -L INPUT -n
```

#### Symptom: Security audit failures

```bash
# Diagnosis
systemctl status ai-security-audit
journalctl -u ai-security-audit --since "1 day ago"
ls -la /var/log/ssh-security-audit.log

# Resolution
1. Review audit findings: cat /var/log/ssh-security-audit.log
2. Fix identified issues based on recommendations
3. Restart security services: systemctl restart ssh-security-audit
4. Run manual security check: ssh-security-check
```

## Emergency Procedures

### Critical System Failure

```bash
# 1. Immediate assessment
systemctl --failed
journalctl -p err --since "1 hour ago"

# 2. Stop non-essential services
systemctl stop ai-continuous-load-test
systemctl stop ai-load-test-profiles

# 3. Restart core services
systemctl restart ai-provider-optimization
systemctl restart ai-analysis

# 4. Check resource availability
free -h
df -h
iostat -x 1 3

# 5. Escalate if needed
# Contact: System Administrator
# Documentation: /home/olafkfreund/.config/nixos/docs/
```

### Storage Emergency (P510)

```bash
# P510 at 79.6% - emergency cleanup required
# CRITICAL: Run immediately if usage > 85%

# 1. Stop non-essential services
systemctl stop ai-load-test-profiles
systemctl stop ai-continuous-load-test

# 2. Emergency cleanup
systemctl start ai-emergency-storage-cleanup
nix-collect-garbage -d --delete-older-than 1d

# 3. Docker cleanup (if applicable)
docker system prune -af --volumes
docker image prune -af

# 4. Log cleanup
journalctl --vacuum-size=100M
find /var/log -name "*.log" -size +50M -exec truncate -s 10M {} \;

# 5. Monitor progress
watch -n 5 'df -h /'
```

### Network Partition

```bash
# If monitoring server (DEX5550) is unreachable

# 1. Check network connectivity
ping dex5550.home.freundcloud.com
systemctl status networking

# 2. Switch to local monitoring
# Enable local Prometheus/Grafana on affected hosts
systemctl start prometheus
systemctl start grafana

# 3. Preserve logs locally
systemctl stop promtail  # Stop log forwarding
journalctl --since "1 hour ago" > /tmp/emergency-logs.txt

# 4. Continue essential operations
systemctl start ai-quick-validation
ai-cli --status
```

## Maintenance Schedules

### Daily (Automated)

- System validation (ai-system-validation)
- Performance monitoring (ai-performance-monitor)
- Security monitoring (ssh-monitor)
- Log rotation (logrotate)

### Weekly (Automated)

- Load testing (ai-provider-load-test)
- Security audits (ai-security-audit)
- Storage analysis (ai-storage-analysis)
- Performance optimization (ai-system-optimization)

### Monthly (Manual)

- Review security logs and update configurations
- Update AI provider configurations
- Performance tuning based on monitoring data
- Backup critical configurations
- Review and update documentation

### Quarterly (Manual)

- Full system security audit
- Performance baseline review
- Infrastructure capacity planning
- Documentation updates
- Disaster recovery testing

## Monitoring and Alerting

### Key Metrics to Monitor

- AI provider response times (target: <5s)
- System resource usage (CPU <80%, Memory <85%)
- Storage usage (especially P510: current 79.6%)
- SSH security events
- Service availability

### Alert Thresholds

- **Critical**: Storage >85%, Memory >90%, AI response >10s
- **Warning**: Storage >70%, Memory >80%, AI response >5s
- **Info**: New SSH connections, service restarts

### Dashboard Links

- [AI Production Overview](http://dex5550.home.freundcloud.com:3001/d/ai-production-overview)
- [AI Security Dashboard](http://dex5550.home.freundcloud.com:3001/d/ai-security-dashboard)
- [AI Performance Dashboard](http://dex5550.home.freundcloud.com:3001/d/ai-performance-dashboard)

## Backup and Recovery

### Critical Data Locations

- `/etc/ai-providers.json` - AI provider configurations
- `/var/lib/ai-analysis/` - Analysis data and reports
- `/var/lib/grafana/dashboards/` - Dashboard configurations
- `/etc/prometheus/` - Monitoring configurations
- `/run/agenix/` - Encrypted secrets (managed by agenix)

### Backup Commands

```bash
# Create backup
tar -czf /tmp/ai-backup-$(date +%Y%m%d).tar.gz \
  /etc/ai-providers.json \
  /var/lib/ai-analysis/ \
  /var/lib/grafana/dashboards/ \
  /etc/prometheus/

# Restore from backup
tar -xzf /tmp/ai-backup-YYYYMMDD.tar.gz -C /
systemctl restart grafana prometheus
```

## Configuration Management

### Key Configuration Files

- `/etc/ai-providers.json` - AI provider settings
- `/etc/prometheus/prometheus.yml` - Metrics collection
- `/var/lib/grafana/dashboards/` - Monitoring dashboards
- `/etc/ssh/sshd_config` - SSH security settings

### Making Changes

1. Test changes in development environment
2. Update configuration files
3. Validate syntax: `just check-syntax`
4. Test configuration: `just test-host HOSTNAME`
5. Deploy changes: `just deploy` or `just HOSTNAME`
6. Monitor for issues post-deployment

## Contact Information

- **Primary Administrator**: System Administrator
- **Documentation**: `/home/olafkfreund/.config/nixos/docs/`
- **Configuration Repository**: `/home/olafkfreund/.config/nixos/`
- **Issue Tracking**: Local system logs and monitoring dashboards

---

_Last Updated: $(date)_
_Version: 1.0_
_Next Review: $(date -d "+1 month")_
