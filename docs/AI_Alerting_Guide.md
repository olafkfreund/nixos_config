# AI Advanced Alerting and Notification System Guide

## Overview

This guide provides comprehensive information about the advanced alerting and notification system for the AI infrastructure. It covers configuration, usage, troubleshooting, and best practices for managing alerts across all notification channels.

## Architecture

### Alerting Components
- **Alert Manager**: Core service that monitors system metrics and triggers alerts
- **Notification Channels**: Email, Slack, SMS, Discord (configurable)
- **Alert Dashboard**: Grafana dashboard for alert visualization
- **Escalation Engine**: Automated escalation based on time and severity
- **Suppression Rules**: Intelligent alert filtering and suppression

### Current Configuration
- **Email**: ✅ Enabled (primary channel)
- **Slack**: ❌ Disabled (configurable)
- **SMS**: ❌ Disabled (configurable)
- **Discord**: ❌ Disabled (configurable)
- **Maintenance Mode**: ❌ Disabled

## Alert Levels and Thresholds

### Alert Levels
1. **Critical**: Immediate attention required
   - Email: ✅ Enabled
   - Slack: Configurable
   - SMS: Configurable
   - Discord: Configurable

2. **Warning**: Attention needed soon
   - Email: ✅ Enabled
   - Slack: Configurable
   - SMS: ❌ Disabled
   - Discord: ❌ Disabled

3. **Info**: Informational only
   - Email: ❌ Disabled
   - Slack: ❌ Disabled
   - SMS: ❌ Disabled
   - Discord: ❌ Disabled

### Alert Thresholds (P620 Configuration)
- **Disk Usage**: 80% (Critical)
- **Memory Usage**: 85% (Critical)
- **CPU Usage**: 80% (Warning)
- **AI Response Time**: 8000ms (Warning)
- **SSH Failed Attempts**: 15 attempts (Critical)
- **Service Downtime**: 300 seconds (Critical)
- **Load Test Failures**: 50% failure rate (Warning)

## Alert Management Commands

### Basic Alert Management
```bash
# Check alert system status
ai-alert-status

# View recent alert history
ai-alert-history

# View last 100 alerts
ai-alert-history 100

# Send test alert
ai-alert-test info "Test message"
ai-alert-test warning "Test warning"
ai-alert-test critical "Test critical alert"

# Check maintenance mode
ai-alert-maintenance-mode status
```

### Shell Aliases
```bash
# Quick aliases available
alert-status          # Check alert system status
alert-test           # Send test alert
alert-history        # View alert history
alert-maintenance    # Maintenance mode management
```

### Service Management
```bash
# Check alert manager service
systemctl status ai-alert-manager

# Restart alert manager
systemctl restart ai-alert-manager

# Check alert manager logs
journalctl -u ai-alert-manager -f

# Check alert dashboard service
systemctl status ai-alert-dashboard
```

## Notification Channels

### Email Notifications
**Configuration**:
- SMTP Server: smtp.gmail.com:587
- From Address: ai-alerts@freundcloud.com
- Recipients: admin@freundcloud.com

**Setup**:
1. Configure SMTP credentials (if using authenticated SMTP)
2. Test email delivery: `ai-alert-test critical "Email test"`
3. Verify email reception

**Email Format**:
```
Subject: [AI Alert] Critical Disk Usage on p620
From: ai-alerts@freundcloud.com
To: admin@freundcloud.com

AI Infrastructure Alert
Level: critical
Time: 2025-07-09 10:30:00
Host: p620

Disk usage is at 82% (threshold: 80%)

This is an automated alert from the AI infrastructure monitoring system.
```

### Slack Notifications (Optional)
**Configuration**:
```nix
ai.alerting = {
  enableSlack = true;
  slackWebhook = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL";
  
  alertLevels = {
    critical = {
      slack = true;
    };
    warning = {
      slack = true;
    };
  };
};
```

**Setup**:
1. Create Slack webhook URL
2. Configure webhook in NixOS configuration
3. Test Slack delivery: `ai-alert-test critical "Slack test"`

### Discord Notifications (Optional)
**Configuration**:
```nix
ai.alerting = {
  enableDiscord = true;
  discordWebhook = "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL";
  
  alertLevels = {
    critical = {
      discord = true;
    };
  };
};
```

**Setup**:
1. Create Discord webhook URL
2. Configure webhook in NixOS configuration
3. Test Discord delivery: `ai-alert-test critical "Discord test"`

### SMS Notifications (Optional)
**Configuration**:
```nix
ai.alerting = {
  enableSms = true;
  
  alertLevels = {
    critical = {
      sms = true;
    };
  };
};
```

**Note**: SMS requires additional service provider integration (Twilio, AWS SNS, etc.)

## Alert Types and Monitoring

### System Resource Alerts

#### Critical Disk Usage
- **Threshold**: 80% (P620)
- **Level**: Critical
- **Channels**: Email
- **Action**: Immediate cleanup required

#### Critical Memory Usage
- **Threshold**: 85%
- **Level**: Critical
- **Channels**: Email
- **Action**: Memory optimization needed

#### High CPU Usage
- **Threshold**: 80%
- **Level**: Warning
- **Channels**: Email
- **Action**: Performance investigation

### AI Service Alerts

#### AI Provider Response Time
- **Threshold**: 8000ms (P620)
- **Level**: Warning
- **Channels**: Email
- **Action**: Performance optimization

#### AI Service Failures
- **Condition**: Any AI service failed
- **Level**: Critical
- **Channels**: Email
- **Action**: Service restart required

#### Load Test Failures
- **Threshold**: 50% failure rate
- **Level**: Warning
- **Channels**: Email
- **Action**: Performance analysis

### Security Alerts

#### SSH Failed Attempts
- **Threshold**: 15 attempts in 5 minutes
- **Level**: Critical
- **Channels**: Email
- **Action**: Security investigation

#### Security Service Failures
- **Condition**: SSH or fail2ban service failed
- **Level**: Critical
- **Channels**: Email
- **Action**: Security service restart

## Escalation Rules

### Level 1 Escalation (5 minutes)
- **Recipients**: admin@freundcloud.com
- **Channels**: Email
- **Action**: Initial notification

### Level 2 Escalation (15 minutes)
- **Recipients**: admin@freundcloud.com, oncall@freundcloud.com
- **Channels**: Email, Slack (if enabled)
- **Action**: Escalated notification

### Level 3 Escalation (30 minutes)
- **Recipients**: admin@freundcloud.com, oncall@freundcloud.com, emergency@freundcloud.com
- **Channels**: Email, Slack, SMS (if enabled)
- **Action**: Emergency escalation

## Alert Suppression and Filtering

### Suppression Rules
The following patterns are automatically suppressed:
- "health check"
- "connection established"  
- "connection closed"
- "router dispatching"
- "body-parser"

### Maintenance Mode
When maintenance mode is enabled:
- Critical alerts: Still sent
- Warning alerts: Suppressed
- Info alerts: Suppressed

**Enable Maintenance Mode**:
```nix
ai.alerting = {
  maintenanceMode = true;
};
```

**Check Maintenance Mode**:
```bash
ai-alert-maintenance-mode status
```

## Alert Dashboard

### Grafana Dashboard
**URL**: http://dex5550.home.freundcloud.com:3001/d/ai-alert-management

**Key Panels**:
1. **Alert Manager Status** - Service health
2. **Active Alerts by Level** - Current alert distribution
3. **Alert Notifications Sent** - Notification rate by channel
4. **System Resource Alerts** - Resource usage trends
5. **AI Provider Performance** - Performance metrics
6. **Recent Alert History** - Log of recent alerts

### Dashboard Management
```bash
# Check dashboard status
ai-dashboard-status

# Reload alert dashboard
systemctl start ai-alert-dashboard

# View dashboard logs
journalctl -u ai-alert-dashboard --since "1 hour ago"
```

## Configuration Examples

### Basic Email-Only Configuration
```nix
ai.alerting = {
  enable = true;
  enableEmail = true;
  enableSlack = false;
  enableSms = false;
  enableDiscord = false;
  
  fromEmail = "alerts@yourcompany.com";
  alertRecipients = ["admin@yourcompany.com"];
  
  alertThresholds = {
    diskUsage = 80;
    memoryUsage = 85;
    cpuUsage = 80;
  };
};
```

### Multi-Channel Configuration
```nix
ai.alerting = {
  enable = true;
  enableEmail = true;
  enableSlack = true;
  enableDiscord = true;
  
  fromEmail = "alerts@yourcompany.com";
  alertRecipients = ["admin@yourcompany.com" "oncall@yourcompany.com"];
  slackWebhook = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL";
  discordWebhook = "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL";
  
  alertLevels = {
    critical = {
      email = true;
      slack = true;
      discord = true;
    };
    warning = {
      email = true;
      slack = true;
      discord = false;
    };
  };
};
```

### Production Configuration with Escalation
```nix
ai.alerting = {
  enable = true;
  enableEmail = true;
  enableSlack = true;
  enableSms = true;
  
  alertRecipients = ["admin@company.com"];
  slackWebhook = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL";
  
  escalationRules = {
    level1 = {
      timeMinutes = 5;
      recipients = ["admin@company.com"];
      channels = ["email"];
    };
    level2 = {
      timeMinutes = 15;
      recipients = ["admin@company.com" "oncall@company.com"];
      channels = ["email" "slack"];
    };
    level3 = {
      timeMinutes = 30;
      recipients = ["admin@company.com" "oncall@company.com" "emergency@company.com"];
      channels = ["email" "slack" "sms"];
    };
  };
};
```

## Troubleshooting

### Alert Manager Not Starting
**Symptoms**: `systemctl start ai-alert-manager` fails
**Diagnosis**:
```bash
systemctl status ai-alert-manager
journalctl -u ai-alert-manager --since "1 hour ago"
```
**Resolution**:
1. Check configuration syntax
2. Verify network connectivity
3. Check log permissions
4. Restart service: `systemctl restart ai-alert-manager`

### Alerts Not Being Sent
**Symptoms**: No alert notifications received
**Diagnosis**:
```bash
ai-alert-status
journalctl -u ai-alert-manager -f
ai-alert-test critical "Test alert"
```
**Resolution**:
1. Check alert manager service status
2. Verify notification channel configuration
3. Test notification channels individually
4. Check alert thresholds and current metrics

### Email Notifications Not Working
**Symptoms**: Email alerts not received
**Diagnosis**:
```bash
# Check SMTP configuration
cat /etc/ai-alerting.json | jq '.smtp'

# Test email sending
ai-alert-test critical "Email test"

# Check logs
journalctl -u ai-alert-manager | grep -i email
```
**Resolution**:
1. Verify SMTP server configuration
2. Check email credentials (if required)
3. Test SMTP connectivity: `telnet smtp.gmail.com 587`
4. Check spam/junk folders

### Slack Notifications Not Working
**Symptoms**: Slack alerts not received
**Diagnosis**:
```bash
# Check webhook configuration
cat /etc/ai-alerting.json | jq '.slack'

# Test webhook
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test"}' \
  YOUR_SLACK_WEBHOOK_URL

# Check logs
journalctl -u ai-alert-manager | grep -i slack
```
**Resolution**:
1. Verify webhook URL is correct
2. Check Slack workspace permissions
3. Test webhook manually
4. Check network connectivity

### Too Many Alerts
**Symptoms**: Alert spam or excessive notifications
**Diagnosis**:
```bash
ai-alert-history | head -20
ai-alert-status
```
**Resolution**:
1. Review alert thresholds (may be too low)
2. Add suppression rules for noisy alerts
3. Enable maintenance mode temporarily
4. Adjust alert levels and channels

### Missing Critical Alerts
**Symptoms**: Important alerts not being sent
**Diagnosis**:
```bash
ai-alert-status
# Check current system metrics
df -h /
free -h
systemctl status ai-*
```
**Resolution**:
1. Check alert thresholds (may be too high)
2. Verify alert manager is running
3. Check if maintenance mode is enabled
4. Review suppression rules

## Best Practices

### Alert Configuration
1. **Start Conservative**: Begin with higher thresholds, lower gradually
2. **Test Thoroughly**: Test all notification channels before deployment
3. **Monitor Alert Volume**: Avoid alert fatigue with proper thresholds
4. **Use Suppression**: Filter out noisy, non-actionable alerts

### Notification Channels
1. **Email for All**: Email should be the primary channel
2. **Slack for Teams**: Use Slack for team coordination
3. **SMS for Critical**: Reserve SMS for true emergencies
4. **Discord for Communities**: Use Discord for community-based monitoring

### Escalation Rules
1. **Timely Escalation**: Don't wait too long between escalation levels
2. **Clear Recipients**: Ensure escalation recipients are always available
3. **Channel Progression**: Start with email, escalate to more urgent channels
4. **Emergency Contacts**: Always have emergency contacts for level 3

### Maintenance and Monitoring
1. **Regular Testing**: Test alert system weekly
2. **Review Thresholds**: Adjust thresholds based on system behavior
3. **Monitor Alert Volume**: Track alert frequency and adjust
4. **Update Contacts**: Keep recipient lists current

## Integration with Other Systems

### Prometheus Integration
The alert system integrates with Prometheus for metrics:
```bash
# Query alert-related metrics
curl -s 'http://localhost:9090/api/v1/query?query=up{job="ai-alert-manager"}'
```

### Grafana Integration
Alert dashboard is automatically provisioned in Grafana:
- Dashboard ID: ai-alert-management
- Refresh: 30 seconds
- Panels: 6 key monitoring panels

### Log Integration
Alert logs are integrated with systemd journal:
```bash
# View alert logs
journalctl -u ai-alert-manager -f

# Search alert logs
journalctl -u ai-alert-manager --since "1 hour ago" | grep -i critical
```

---

*This alerting guide should be used with the Operations Runbook and other documentation.*
*Test all notification channels before relying on them for production alerts.*
*Last Updated: $(date)*