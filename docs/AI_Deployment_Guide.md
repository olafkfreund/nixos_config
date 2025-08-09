# AI Infrastructure Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the AI infrastructure across the NixOS environment, including initial setup, configuration, and ongoing maintenance.

## Prerequisites

### System Requirements

- NixOS 25.11 or later
- Flakes enabled
- SSH access to all hosts
- Internet connectivity for API providers

### Required Secrets

- `api-anthropic` - Anthropic Claude API key
- `api-openai` - OpenAI API key
- `api-gemini` - Google Gemini API key
- User password secrets (managed via agenix)

## Initial Deployment

### Step 1: Configure Secrets

```bash
# Navigate to configuration directory
cd /home/olafkfreund/.config/nixos

# Create required API keys
./scripts/manage-secrets.sh create api-anthropic
./scripts/manage-secrets.sh create api-openai
./scripts/manage-secrets.sh create api-gemini

# Verify secrets are created
./scripts/manage-secrets.sh status
```

### Step 2: Enable AI Infrastructure

Edit the host configuration to enable AI features:

```nix
# hosts/HOSTNAME/configuration.nix
ai.providers = {
  enable = true;
  defaultProvider = "anthropic";
  enableFallback = true;

  # Enable specific providers
  openai.enable = true;
  anthropic.enable = true;
  gemini.enable = true;
  ollama.enable = true;
};

# Enable AI-powered system analysis
ai.analysis = {
  enable = true;
  aiProvider = "anthropic";
  enableFallback = true;

  features = {
    performanceAnalysis = true;
    resourceOptimization = true;
    configDriftDetection = true;
    predictiveMaintenance = true;
    logAnalysis = true;
    securityAnalysis = true;
  };
};
```

### Step 3: Configure Monitoring

Enable monitoring based on host role:

**For Monitoring Server (DEX5550)**:

```nix
monitoring = {
  enable = true;
  mode = "server";  # Central monitoring server

  features = {
    prometheus = true;
    grafana = true;
    alerting = true;
    logging = true;
    nodeExporter = true;
    nixosMetrics = true;
  };
};
```

**For Monitored Hosts (P620, P510, Razer)**:

```nix
monitoring = {
  enable = true;
  mode = "client";  # Send data to monitoring server
  serverHost = "dex5550";

  features = {
    nodeExporter = true;
    nixosMetrics = true;
    logging = true;
    # Host-specific features
    amdGpuMetrics = true;  # For P620
    # nvidiaGpuMetrics = true;  # For P510, Razer
  };
};
```

### Step 4: Test Configuration

```bash
# Validate configuration syntax
just check-syntax

# Test specific host configuration
just test-host p620
just test-host dex5550

# Test all hosts
just test-all
```

### Step 5: Deploy Configuration

```bash
# Deploy to specific host
just p620
just dex5550
just p510
just razer

# Or deploy to local system
just deploy
```

## Host-Specific Deployment

### P620 (AMD Workstation) - Primary AI Host

**Role**: AI development, local inference, monitoring client

**Configuration Features**:

- AI providers (Anthropic, Ollama)
- Performance optimization
- Load testing
- SSH hardening
- Production dashboard

**Deployment Steps**:

```bash
# 1. Test configuration
just test-host p620

# 2. Deploy
just p620

# 3. Verify services
ssh p620 'systemctl status ai-*'

# 4. Test AI functionality
ssh p620 'ai-cli --status'

# 5. Test local inference
ssh p620 'ai-cli -p ollama "test"'
```

**Post-Deployment Verification**:

```bash
# Check AI provider status
ssh p620 'ai-cli --status'

# Check Ollama service
ssh p620 'systemctl status ollama'

# Check monitoring client
ssh p620 'systemctl status node-exporter'

# Test load testing
ssh p620 'ai-load-test light'
```

### DEX5550 (Intel SFF) - Monitoring Server

**Role**: Centralized monitoring, metrics collection

**Configuration Features**:

- Prometheus server
- Grafana dashboards
- Alertmanager
- Log collection (Loki)

**Deployment Steps**:

```bash
# 1. Test configuration
just test-host dex5550

# 2. Deploy
just dex5550

# 3. Verify monitoring services
ssh dex5550 'systemctl status prometheus grafana alertmanager'

# 4. Check dashboard provisioning
ssh dex5550 'ls -la /var/lib/grafana/dashboards/'

# 5. Test web interfaces
curl -f http://dex5550.home.freundcloud.com:3001/api/health
curl -f http://dex5550.home.freundcloud.com:9090/-/healthy
```

**Post-Deployment Verification**:

```bash
# Check Prometheus targets
curl -s http://dex5550.home.freundcloud.com:9090/api/v1/targets | jq '.data.activeTargets[].health'

# Check Grafana dashboards
curl -s http://dex5550.home.freundcloud.com:3001/api/dashboards/home

# Verify alertmanager
curl -s http://dex5550.home.freundcloud.com:9093/api/v1/status
```

### P510 (Intel Xeon) - High Storage Monitoring

**Role**: High-performance computing, critical storage monitoring

**Configuration Features**:

- Storage analysis (emergency mode)
- Memory optimization
- Automated remediation
- Security auditing

**Deployment Steps**:

```bash
# 1. Check current storage usage
ssh p510 'df -h /'

# 2. Test configuration
just test-host p510

# 3. Deploy
just p510

# 4. Verify storage monitoring
ssh p510 'systemctl status ai-storage-analysis'

# 5. Test emergency cleanup
ssh p510 'systemctl start ai-emergency-storage-cleanup'
```

**Post-Deployment Verification**:

```bash
# Check storage analysis
ssh p510 'systemctl status ai-storage-analysis'

# Check emergency cleanup capability
ssh p510 'systemctl status ai-emergency-storage-cleanup'

# Monitor storage usage
ssh p510 'df -h / && du -sh /nix/store'
```

### Razer (Intel/NVIDIA Laptop) - Mobile Platform

**Role**: Mobile development, monitoring client

**Configuration Features**:

- Basic AI providers
- Mobile-optimized monitoring
- Power management integration

**Deployment Steps**:

```bash
# 1. Test configuration
just test-host razer

# 2. Deploy
just razer

# 3. Verify mobile features
ssh razer 'systemctl status ai-providers'

# 4. Check power management
ssh razer 'powertop --help'
```

## Service Configuration

### AI Provider Services

After deployment, configure AI providers:

```bash
# Test AI provider connectivity
ai-cli --status

# Test individual providers
ai-cli -p anthropic "test deployment"
ai-cli -p openai "test deployment"
ai-cli -p gemini "test deployment"
ai-cli -p ollama "test deployment"

# Check AI provider optimization
systemctl status ai-provider-optimization
```

### Monitoring Services

Configure monitoring after deployment:

```bash
# On monitoring server (DEX5550)
systemctl status prometheus grafana alertmanager

# Check dashboard provisioning
ai-dashboard-status

# Test monitoring connectivity
prometheus-status
grafana-status
```

### Security Services

Configure security features:

```bash
# Check SSH hardening
ssh-security-check

# Verify fail2ban
systemctl status fail2ban

# Test security audit
systemctl start ai-security-audit
```

## Verification and Testing

### Comprehensive System Test

```bash
#!/bin/bash
# Comprehensive deployment verification

echo "=== AI Infrastructure Deployment Verification ==="
echo "Date: $(date)"
echo

# Test AI providers
echo "=== AI Provider Testing ==="
for provider in anthropic openai gemini ollama; do
    echo "Testing $provider..."
    if timeout 30 ai-cli -p "$provider" "test deployment" &>/dev/null; then
        echo "  $provider: ✓ PASS"
    else
        echo "  $provider: ✗ FAIL"
    fi
done
echo

# Test monitoring
echo "=== Monitoring System Testing ==="
echo "Prometheus targets:"
curl -s http://dex5550.home.freundcloud.com:9090/api/v1/targets | jq -r '.data.activeTargets[] | .labels.instance + ": " + .health'

echo "Grafana health:"
curl -f http://dex5550.home.freundcloud.com:3001/api/health &>/dev/null && echo "  Grafana: ✓ HEALTHY" || echo "  Grafana: ✗ UNHEALTHY"

echo "Alertmanager status:"
curl -f http://dex5550.home.freundcloud.com:9093/api/v1/status &>/dev/null && echo "  Alertmanager: ✓ HEALTHY" || echo "  Alertmanager: ✗ UNHEALTHY"
echo

# Test security
echo "=== Security Testing ==="
echo "SSH security:"
ssh-security-check | grep -E "(PASS|FAIL)" | head -3

echo "Fail2ban status:"
systemctl is-active fail2ban &>/dev/null && echo "  Fail2ban: ✓ ACTIVE" || echo "  Fail2ban: ✗ INACTIVE"
echo

# Test performance
echo "=== Performance Testing ==="
echo "Running light load test..."
ai-load-test light &>/dev/null && echo "  Load test: ✓ PASS" || echo "  Load test: ✗ FAIL"

echo "System resources:"
free -h | grep Mem | awk '{print "  Memory: " $3 "/" $2 " (" int($3/$2*100) "%)"}'
df -h / | tail -1 | awk '{print "  Disk: " $3 "/" $2 " (" $5 ")"}'
echo

echo "=== Deployment Verification Complete ==="
```

### Load Testing After Deployment

```bash
# Run comprehensive load test
ai-load-test moderate

# Check load test results
ai-load-test-report

# Verify performance metrics
ai-dashboard-status
```

## Troubleshooting Deployment Issues

### Common Deployment Problems

#### Build Failures

**Symptoms**: `just test-host` or `just deploy` fails
**Diagnosis**:

```bash
# Check syntax
just check-syntax

# Check for missing dependencies
nix flake check

# Check specific error
just test-host p620 2>&1 | grep -E "(error|failed)"
```

**Resolution**:

1. Fix syntax errors
2. Add missing dependencies
3. Check flake.lock for version conflicts
4. Rebuild with clean environment

#### Service Start Failures

**Symptoms**: AI services fail to start after deployment
**Diagnosis**:

```bash
# Check service status
systemctl status ai-*

# Check logs
journalctl -u ai-providers --since "10 minutes ago"

# Check dependencies
systemctl list-dependencies ai-providers
```

**Resolution**:

1. Check service configuration
2. Verify dependencies are met
3. Check API key availability
4. Restart services in order

#### API Key Issues

**Symptoms**: AI providers not working after deployment
**Diagnosis**:

```bash
# Check API key existence
ls -la /run/agenix/api-*

# Check API key permissions
ls -la /run/agenix/ | grep api-

# Test API key validity
./scripts/manage-secrets.sh status
```

**Resolution**:

1. Recreate API keys: `./scripts/manage-secrets.sh create api-anthropic`
2. Update secret permissions
3. Restart agenix service: `systemctl restart agenix`
4. Restart AI services

### Monitoring Deployment Issues

#### Grafana Not Accessible

**Symptoms**: Cannot access Grafana dashboard
**Diagnosis**:

```bash
# Check Grafana service
systemctl status grafana

# Check network connectivity
curl -f http://localhost:3001/api/health

# Check firewall
firewall-cmd --list-ports | grep 3001
```

**Resolution**:

1. Start Grafana: `systemctl start grafana`
2. Check network configuration
3. Open firewall ports
4. Verify dashboard provisioning

#### Prometheus Not Scraping

**Symptoms**: No metrics in Prometheus
**Diagnosis**:

```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets

# Check exporters
systemctl status node-exporter nixos-exporter

# Check network connectivity
ping target-host
```

**Resolution**:

1. Start exporters on target hosts
2. Check network connectivity
3. Verify Prometheus configuration
4. Restart Prometheus service

## Maintenance and Updates

### Regular Maintenance Tasks

#### Weekly

```bash
# Update flake inputs
just update-flake

# Test all configurations
just test-all

# Deploy updates
just deploy

# Run comprehensive testing
./deployment-verification.sh
```

#### Monthly

```bash
# Update AI provider configurations
systemctl restart ai-provider-optimization

# Review monitoring dashboards
ai-dashboard-status

# Check security audit results
systemctl start ai-security-audit

# Update documentation
# Review and update deployment procedures
```

#### Quarterly

```bash
# Full system validation
just validate

# Performance baseline review
ai-load-test stress

# Security assessment
ssh-security-check
systemctl start ai-security-audit

# Capacity planning review
# Analyze storage and resource trends
```

### Update Procedures

#### Adding New Hosts

1. Create host configuration directory
2. Add host to flake.nix
3. Configure monitoring client/server
4. Deploy configuration
5. Verify monitoring integration

#### Adding New AI Providers

1. Create provider configuration
2. Add API key secret
3. Update provider list
4. Test provider functionality
5. Update monitoring dashboards

#### Scaling Infrastructure

1. Analyze current capacity
2. Plan resource allocation
3. Update host configurations
4. Deploy changes gradually
5. Monitor performance impact

## Backup and Recovery

### Critical Configuration Backup

```bash
# Backup configuration
tar -czf /tmp/ai-config-backup-$(date +%Y%m%d).tar.gz \
  /home/olafkfreund/.config/nixos \
  /etc/ai-providers.json \
  /var/lib/grafana/dashboards

# Backup monitoring data
tar -czf /tmp/ai-monitoring-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/prometheus \
  /var/lib/grafana \
  /etc/prometheus
```

### Recovery Procedures

```bash
# Restore configuration
tar -xzf /tmp/ai-config-backup-YYYYMMDD.tar.gz -C /

# Rebuild and deploy
just deploy

# Restore monitoring data
tar -xzf /tmp/ai-monitoring-backup-YYYYMMDD.tar.gz -C /
systemctl restart prometheus grafana
```

## Best Practices

### Deployment Best Practices

1. **Test First**: Always test configurations before deployment
2. **Incremental Updates**: Deploy changes gradually
3. **Monitor Impact**: Watch for issues after deployment
4. **Document Changes**: Keep deployment logs and notes

### Security Best Practices

1. **Rotate API Keys**: Regularly update API keys
2. **Monitor Access**: Watch for unauthorized access
3. **Update Security**: Keep security configurations current
4. **Audit Regularly**: Run security audits frequently

### Performance Best Practices

1. **Baseline Performance**: Establish performance baselines
2. **Regular Testing**: Run load tests regularly
3. **Monitor Trends**: Track performance over time
4. **Optimize Proactively**: Address issues before they become critical

---

## Latest Deployment Status

**Deployment Completed**: July 9, 2025 at 23:52:28 BST

### Deployment Summary

✅ **All 4 hosts successfully deployed**
✅ **Enterprise-grade monitoring active**
✅ **Multi-provider AI system operational**
✅ **Advanced alerting system functional**
✅ **Security hardening applied**
✅ **Performance optimization enabled**

### Validation Results

- **Connectivity**: All hosts reachable and SSH accessible
- **AI Services**: P620 with Ollama (6 models), API providers active
- **Monitoring**: DEX5550 server with P620/P510/Razer clients
- **Alerting**: P620 alert manager functional with email notifications
- **Security**: SSH hardening and fail2ban active on critical hosts
- **Performance**: All systems within healthy resource usage

### Access Points (Production Ready)

- **Grafana**: <http://dex5550.home.freundcloud.com:3001>
- **Prometheus**: <http://dex5550.home.freundcloud.com:9090>
- **Alertmanager**: <http://dex5550.home.freundcloud.com:9093>

### Validation Command

```bash
# Run comprehensive deployment validation
./scripts/deployment-validation.sh
```

---

_This deployment guide should be used with the Operations Runbook and other documentation._
_Always test configurations before production deployment._
_Last Updated: July 9, 2025 - Production Deployment Complete_
