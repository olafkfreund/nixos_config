# AI Infrastructure Monitoring Guide

## Overview

This guide provides comprehensive information about monitoring the AI infrastructure, including dashboard usage, metric interpretation, alerting, and performance analysis.

## Monitoring Architecture

### Current Setup

- **Monitoring Server**: DEX5550 (Intel SFF) - Centralized monitoring
- **Monitored Hosts**: P620 (AMD), P510 (Intel Xeon), Razer (Intel/NVIDIA)
- **Monitoring Stack**: Prometheus + Grafana + Alertmanager + Node Exporters

### Service Endpoints

- **Grafana**: <http://dex5550.home.freundcloud.com:3001>
- **Prometheus**: <http://dex5550.home.freundcloud.com:9090>
- **Alertmanager**: <http://dex5550.home.freundcloud.com:9093>

## Dashboard Overview

### AI Production Overview Dashboard

**URL**: <http://dex5550.home.freundcloud.com:3001/d/ai-production-overview>

**Key Panels**:

1. **System Health Overview** - Shows up/down status of all hosts
2. **AI Analysis Services Status** - AI service availability
3. **AI Provider Response Times** - Response time trends by provider
4. **System Resource Usage** - CPU and memory usage across hosts
5. **Storage Usage by Host** - Disk usage with critical thresholds
6. **SSH Security Monitoring** - Failed login attempts and banned IPs
7. **AI Analysis Success Rate** - Success rate of AI operations
8. **Performance Optimization Status** - Last optimization run time
9. **Service Uptime** - How long services have been running
10. **Critical Alerts** - Recent critical system events

**Refresh Rate**: 30 seconds

### AI Security Dashboard

**URL**: <http://dex5550.home.freundcloud.com:3001/d/ai-security-dashboard>

**Key Panels**:

1. **SSH Connection Attempts** - Total and failed SSH attempts over time
2. **Security Audit Status** - Last security audit run and findings
3. **Fail2Ban Activity** - Banned IPs and new bans over time

**Refresh Rate**: 30 seconds

### AI Performance Dashboard

**URL**: <http://dex5550.home.freundcloud.com:3001/d/ai-performance-dashboard>

**Key Panels**:

1. **AI Provider Performance Comparison** - Response times by provider
2. **Performance Optimization History** - Optimization runs and improvements
3. **Cache Performance** - Cache hit rates and cache size

**Refresh Rate**: 30 seconds

## Key Metrics and Interpretation

### System Health Metrics

#### Host Availability

- **Metric**: `up{job="node-exporter"}`
- **Normal**: 1 (up), 0 (down)
- **Alert**: Any host showing 0 for >5 minutes

#### CPU Usage

- **Metric**: `100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
- **Normal**: <70%
- **Warning**: 70-80%
- **Critical**: >80%

#### Memory Usage

- **Metric**: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`
- **Normal**: <75%
- **Warning**: 75-85%
- **Critical**: >85%

#### Disk Usage

- **Metric**: `100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)`
- **Normal**: <60%
- **Warning**: 60-70%
- **Critical**: >70%
- **Emergency**: >85% (P510 currently at 79.6%)

### AI Service Metrics

#### AI Provider Response Times

- **Metric**: `ai_provider_response_time_ms`
- **Normal**: <3000ms
- **Warning**: 3000-5000ms
- **Critical**: >5000ms
- **Alert**: >10000ms

#### AI Analysis Success Rate

- **Metric**: `(ai_analysis_success_total / ai_analysis_total) * 100`
- **Normal**: >95%
- **Warning**: 90-95%
- **Critical**: <90%

#### AI Service Availability

- **Metric**: `up{job="ai-analysis"}`
- **Normal**: 1 (up)
- **Alert**: 0 (down) for >2 minutes

### Security Metrics

#### SSH Failed Attempts

- **Metric**: `rate(ssh_failed_attempts_total[5m]) * 60`
- **Normal**: <5 attempts/minute
- **Warning**: 5-10 attempts/minute
- **Critical**: >10 attempts/minute

#### Fail2Ban Activity

- **Metric**: `fail2ban_banned_ips_total`
- **Normal**: Occasional bans
- **Alert**: Sudden spike in bans

### Performance Metrics

#### Load Testing Results

- **Metric**: `ai_load_test_success_rate`
- **Normal**: >80%
- **Warning**: 70-80%
- **Critical**: <70%

#### Cache Performance

- **Metric**: `ai_cache_hit_rate`
- **Normal**: >70%
- **Warning**: 50-70%
- **Critical**: <50%

## Alerting Configuration

### Critical Alerts

#### High Disk Usage (P510)

- **Condition**: P510 disk usage >85%
- **Action**: Immediate attention required
- **Recovery**: Run emergency cleanup procedures

#### AI Provider Failures

- **Condition**: AI provider response time >10s or availability <90%
- **Action**: Check provider status and connectivity
- **Recovery**: Restart provider optimization services

#### Memory Exhaustion

- **Condition**: Memory usage >90%
- **Action**: Immediate memory optimization
- **Recovery**: Run memory cleanup procedures

#### SSH Security Breach

- **Condition**: >20 failed SSH attempts in 5 minutes
- **Action**: Security incident response
- **Recovery**: Check logs and block malicious IPs

### Warning Alerts

#### High Resource Usage

- **Condition**: CPU >80% or Memory >85% for >10 minutes
- **Action**: Monitor and optimize if needed
- **Recovery**: Run performance optimization

#### Slow AI Responses

- **Condition**: Average response time >5s for >15 minutes
- **Action**: Performance investigation
- **Recovery**: Restart AI services or optimize

### Information Alerts

#### Service Restarts

- **Condition**: Any AI service restart
- **Action**: Monitor for stability
- **Recovery**: Check service logs

#### Storage Cleanup

- **Condition**: Automated cleanup triggered
- **Action**: Monitor storage trends
- **Recovery**: None required

## Host-Specific Monitoring

### P620 (AMD Workstation)

**Role**: Primary AI development and testing
**Current Status**: Monitoring client

**Key Metrics**:

- AMD GPU utilization (ROCm)
- Ollama service performance
- AI provider response times
- Development workload patterns

**Monitoring Focus**:

- GPU temperature and utilization
- AI model loading times
- Development environment stability
- Local AI inference performance

**Commands**:

```bash
# Check P620 specific metrics
rocm-smi  # GPU status
systemctl status ollama  # Local AI service
ai-cli -p ollama "test"  # Test local inference
```

### DEX5550 (Intel SFF)

**Role**: Monitoring server
**Current Status**: Centralized monitoring hub

**Key Metrics**:

- Prometheus scrape success rate
- Grafana dashboard responsiveness
- Alertmanager notification delivery
- Metrics storage usage

**Monitoring Focus**:

- Monitoring service availability
- Metrics ingestion rate
- Dashboard performance
- Alert processing time

**Commands**:

```bash
# Check DEX5550 monitoring services
systemctl status prometheus grafana alertmanager
prometheus-status  # Check targets
grafana-status     # Check dashboards
```

### P510 (Intel Xeon)

**Role**: High-performance computing
**Current Status**: Critical storage monitoring (79.6% usage)

**Key Metrics**:

- Storage usage trends
- NVIDIA GPU utilization
- Compute workload performance
- Storage I/O patterns

**Monitoring Focus**:

- **CRITICAL**: Disk usage monitoring
- Storage cleanup automation
- Compute performance optimization
- GPU utilization tracking

**Commands**:

```bash
# Check P510 critical metrics
df -h /  # Monitor disk usage
nvidia-smi  # GPU status
systemctl status ai-storage-analysis
```

### Razer (Intel/NVIDIA Laptop)

**Role**: Mobile development platform
**Current Status**: Monitoring client

**Key Metrics**:

- Battery and power management
- Hybrid GPU switching
- Network connectivity
- Mobile workload patterns

**Monitoring Focus**:

- Power consumption
- Thermal management
- Network stability
- Mobile development productivity

**Commands**:

```bash
# Check Razer mobile metrics
powertop  # Power consumption
nvidia-smi  # GPU status
ping dex5550.home.freundcloud.com  # Network connectivity
```

## Monitoring Commands

### Daily Health Check

```bash
#!/bin/bash
# Daily monitoring health check

echo "=== Daily AI Infrastructure Health Check ==="
echo "Date: $(date)"
echo

# Check monitoring services
echo "=== Monitoring Services ==="
systemctl status prometheus grafana alertmanager --no-pager | grep -E "(Active|Main PID)"
echo

# Check AI service status
echo "=== AI Services Status ==="
systemctl status ai-* --no-pager | grep -E "(Active|Main PID|Tasks)"
echo

# Check critical metrics
echo "=== Critical Metrics ==="
echo "Host availability:"
curl -s http://localhost:9090/api/v1/query?query=up | jq -r '.data.result[] | .metric.instance + ": " + .value[1]'
echo

echo "Storage usage:"
df -h | grep -E "(/$|/mnt)" | awk '{print $6 ": " $5}'
echo

echo "AI provider status:"
if command -v ai-cli &>/dev/null; then
    ai-cli --status
else
    echo "ai-cli not available"
fi
echo

# Check for alerts
echo "=== Active Alerts ==="
curl -s http://localhost:9093/api/v1/alerts | jq -r '.data[] | select(.state == "firing") | .labels.alertname'
echo

# Check recent errors
echo "=== Recent Errors ==="
journalctl -p err --since "24 hours ago" --no-pager | tail -5
```

### Performance Analysis

```bash
#!/bin/bash
# Performance analysis script

echo "=== AI Infrastructure Performance Analysis ==="
echo "Date: $(date)"
echo

# AI provider performance
echo "=== AI Provider Performance ==="
for provider in anthropic ollama; do
    echo "Testing $provider response time..."
    start=$(date +%s%3N)
    if timeout 10 ai-cli -p "$provider" "test" &>/dev/null; then
        end=$(date +%s%3N)
        time=$((end - start))
        echo "$provider: ${time}ms"
    else
        echo "$provider: TIMEOUT"
    fi
done
echo

# Load test analysis
echo "=== Load Test Analysis ==="
if [ -f "/var/lib/ai-analysis/load-test-reports/load_test_$(hostname)_*.json" ]; then
    latest_report=$(ls -t /var/lib/ai-analysis/load-test-reports/load_test_$(hostname)_*.json | head -1)
    echo "Latest load test: $(basename "$latest_report")"
    jq -r '
        "Success Rate: " + (.load_test_summary.success_rate | tostring) + "%",
        "Max CPU: " + (.system_resources.max_cpu_usage | tostring) + "%",
        "Max Memory: " + (.system_resources.max_memory_usage | tostring) + "%"
    ' "$latest_report" 2>/dev/null || echo "Could not parse report"
else
    echo "No load test reports found"
fi
echo

# Resource trends
echo "=== Resource Trends ==="
echo "CPU Usage (last hour):"
curl -s "http://localhost:9090/api/v1/query?query=avg(100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100))" | jq -r '.data.result[0].value[1] + "%"'

echo "Memory Usage (last hour):"
curl -s "http://localhost:9090/api/v1/query?query=avg((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100)" | jq -r '.data.result[0].value[1] + "%"'

echo "Disk Usage:"
df -h / | tail -1 | awk '{print $5}'
```

### Security Monitoring

```bash
#!/bin/bash
# Security monitoring check

echo "=== AI Infrastructure Security Monitoring ==="
echo "Date: $(date)"
echo

# SSH security
echo "=== SSH Security ==="
echo "Failed login attempts (last 24h):"
journalctl -u sshd --since "24 hours ago" | grep -c "Failed password" || echo "0"

echo "Successful logins (last 24h):"
journalctl -u sshd --since "24 hours ago" | grep -c "Accepted" || echo "0"

echo "Fail2ban status:"
if command -v fail2ban-client &>/dev/null; then
    fail2ban-client status ssh 2>/dev/null || echo "Fail2ban not active"
else
    echo "Fail2ban not installed"
fi
echo

# Security audit results
echo "=== Security Audit Results ==="
if [ -f "/var/log/ssh-security-audit.log" ]; then
    echo "Last security audit:"
    tail -10 /var/log/ssh-security-audit.log
else
    echo "No security audit log found"
fi
echo

# AI security
echo "=== AI Security ==="
echo "AI analysis security checks:"
journalctl -u ai-security-audit --since "24 hours ago" --no-pager | tail -5 || echo "No recent security audits"
```

## Troubleshooting Monitoring Issues

### Dashboard Not Loading

1. Check Grafana service: `systemctl status grafana`
2. Check network connectivity: `curl -f http://localhost:3001/api/health`
3. Restart Grafana: `systemctl restart grafana`
4. Check dashboard files: `ls -la /var/lib/grafana/dashboards/`

### Missing Metrics

1. Check Prometheus targets: `curl -s http://localhost:9090/api/v1/targets`
2. Check exporters: `systemctl status node-exporter nixos-exporter`
3. Check network connectivity between hosts
4. Restart Prometheus: `systemctl restart prometheus`

### Alerts Not Firing

1. Check Alertmanager: `systemctl status alertmanager`
2. Check alert rules: `curl -s http://localhost:9090/api/v1/rules`
3. Check notification configuration
4. Test alert delivery: `curl -s http://localhost:9093/api/v1/alerts`

## Best Practices

### Regular Monitoring Tasks

1. **Daily**: Check dashboard for anomalies
2. **Weekly**: Review performance trends
3. **Monthly**: Analyze capacity planning metrics
4. **Quarterly**: Review and update alert thresholds

### Performance Optimization

1. Monitor response time trends
2. Set up automated performance testing
3. Track resource utilization patterns
4. Optimize based on usage patterns

### Security Monitoring

1. Review SSH logs regularly
2. Monitor for unusual access patterns
3. Keep security audit results current
4. Update security configurations based on findings

### Capacity Planning

1. Track storage usage trends (especially P510)
2. Monitor resource growth patterns
3. Plan for scalability requirements
4. Set up proactive alerts for capacity limits

---

_This monitoring guide should be used with the Operations Runbook and Troubleshooting Guide._
_For dashboard access, use the provided URLs and credentials._
_Last Updated: $(date)_
