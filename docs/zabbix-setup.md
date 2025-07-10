# Zabbix Monitoring Setup Guide

## Overview

This guide explains the complete Zabbix monitoring implementation for the NixOS infrastructure, including server setup, agent configuration, SNMP device monitoring, and Grafana integration.

## Architecture

### **Zabbix Server**: DEX5550
- **Database**: SQLite (suitable for small installations)
- **Web Interface**: https://home.freundcloud.com/zabbix
- **Authentication**: Basic auth (admin:zabbix123)
- **Port**: 10051 (server), 8080 (web interface)

### **Zabbix Agents**: All Hosts
- **P620**: AMD workstation agent
- **P510**: Intel Xeon/NVIDIA media server agent  
- **Razer**: Mobile laptop agent
- **DEX5550**: Local agent (in addition to server)
- **Port**: 10050 (all agents)

### **SNMP Monitoring**
- **Deco Routers**: 3 units with public community
- **Google Devices**: Smart home devices (need IP discovery)

### **Grafana Integration**
- **Data Source**: Zabbix plugin
- **URL**: https://home.freundcloud.com/grafana
- **Dashboards**: Network overview, host monitoring

## Module Structure

### Main Module Files
```bash
modules/monitoring/zabbix.nix           # Main configuration interface
modules/monitoring/zabbix-server.nix    # Zabbix server components
modules/monitoring/zabbix-agent.nix     # Zabbix agent components  
modules/monitoring/zabbix-grafana.nix   # Grafana integration
```

### Configuration Pattern
```nix
# Server configuration (DEX5550)
modules.monitoring.zabbix = {
  enable = true;
  mode = "server";
  serverHost = "dex5550";
  snmpDevices = [ ... ];
  grafanaIntegration.enable = true;
};

# Agent configuration (P620, P510, Razer)
modules.monitoring.zabbix = {
  enable = true;
  mode = "agent";
  serverHost = "dex5550";
};
```

## Network Device Discovery

### Finding Deco Router IPs
```bash
# Scan network for Deco devices
nmap -sn 192.168.1.0/24 | grep -B2 -A2 "TP-Link\|Deco"

# Test SNMP connectivity
snmpwalk -v2c -c public 192.168.1.1 1.3.6.1.2.1.1.1.0
```

### Finding Google Device IPs
```bash
# Discover Google devices
nmap -sn 192.168.1.0/24 | grep -B2 -A2 "Google\|Nest"

# Check if SNMP is available (unlikely on consumer Google devices)
snmpwalk -v2c -c public <GOOGLE_DEVICE_IP> 1.3.6.1.2.1.1.1.0
```

### Current SNMP Device Configuration
```nix
snmpDevices = [
  {
    name = "Deco-Main-Router";
    ip = "192.168.1.1";          # Main router
    community = "public";
    template = "Template Net TP-LINK SNMP";
  }
  {
    name = "Deco-Bedroom";  
    ip = "192.168.1.10";         # Replace with actual IP
    community = "public";
    template = "Template Net TP-LINK SNMP";
  }
  {
    name = "Deco-Office";
    ip = "192.168.1.11";         # Replace with actual IP
    community = "public";
    template = "Template Net TP-LINK SNMP";
  }
  # Google devices - likely won't support SNMP
  {
    name = "Google-Home-Living";
    ip = "192.168.1.100";        # Find actual IP
    community = "public";
    template = "Template Net Network Generic Device SNMP";
  }
];
```

## Deployment Process

### 1. Deploy DEX5550 (Zabbix Server)
```bash
# Test configuration
just test-host dex5550

# Deploy server
just quick-deploy dex5550
```

### 2. Deploy All Agents
```bash
# Deploy agents to all hosts
just quick-deploy p620
just quick-deploy p510  
just quick-deploy razer
```

### 3. Verify Installation
```bash
# Check Zabbix server status
ssh dex5550 "systemctl status zabbix-server zabbix-web"

# Check agent status on each host
ssh p620 "systemctl status zabbix-agent2"
ssh p510 "systemctl status zabbix-agent2"
ssh razer "systemctl status zabbix-agent2"
```

## Initial Configuration

### 1. Access Zabbix Web Interface
- **URL**: https://home.freundcloud.com/zabbix
- **Username**: Admin
- **Password**: zabbix (default - should be changed)

### 2. Change Default Password
```bash
# Access web interface and go to:
# Administration → Users → Admin → Change password
```

### 3. Add SNMP Devices
1. Go to **Configuration → Hosts**
2. Click **Create host**
3. Configure each Deco router:
   - **Host name**: Deco-Main-Router
   - **Groups**: Network devices
   - **Interfaces**: SNMP (192.168.1.1:161)
   - **Templates**: Template Net TP-LINK SNMP

### 4. Verify Agent Auto-Registration
- Go to **Configuration → Hosts**
- Check that P620, P510, and Razer appear automatically
- If not, manually add hosts with agent interfaces

## SNMP Device Setup

### Deco Router SNMP Configuration
Most TP-Link Deco routers have SNMP enabled by default with:
- **Community**: public (read-only)
- **Port**: 161
- **Version**: SNMPv2c

### Google Device Limitations
Google Home, Nest, and Chromecast devices typically:
- **Do NOT support SNMP** for security reasons
- Can be monitored via:
  - Network ping/availability
  - Google Assistant API (requires setup)
  - Network traffic analysis
  - Custom integrations

### Alternative Google Device Monitoring
```nix
# For Google devices, use basic network monitoring
{
  name = "Google-Home-Living";
  ip = "192.168.1.100";
  community = "public";
  template = "Template Net ICMP Ping";  # Basic availability only
}
```

## Grafana Integration

### 1. Install Zabbix Plugin
The plugin is automatically provisioned via NixOS configuration.

### 2. Configure Data Source
Data source is automatically configured with:
- **Name**: Zabbix
- **URL**: http://127.0.0.1:8080
- **Username**: Admin
- **Password**: zabbix

### 3. Import Dashboards
Pre-configured dashboards are automatically created:
- **Network Overview**: SNMP device status and traffic
- **Hosts Overview**: Server availability and performance

### 4. Access Dashboards
- **URL**: https://home.freundcloud.com/grafana
- Navigate to **Dashboards → Browse**
- Select Zabbix dashboards

## Monitoring Capabilities

### Host Monitoring (via Agents)
- **System metrics**: CPU, memory, disk usage
- **Network traffic**: Interface statistics
- **Process monitoring**: Service status
- **Log file monitoring**: System logs
- **Custom metrics**: Docker containers, services

### Network Device Monitoring (via SNMP)
- **Interface status**: Up/down state
- **Traffic statistics**: Bytes in/out, packets, errors
- **Device health**: Temperature, CPU usage (if supported)
- **Connectivity**: Ping response times

### Application Monitoring
- **Docker containers**: Status and resource usage
- **NixOS services**: SystemD unit status
- **Web services**: HTTP response monitoring
- **Database monitoring**: If databases are added

## Alerting Configuration

### 1. Configure Email Notifications
```bash
# In Zabbix web interface:
# Administration → Media types → Email
```

### 2. Set Up Alert Rules
- **Host down**: If agent unreachable for 5 minutes
- **High CPU**: If CPU > 90% for 10 minutes  
- **Low disk space**: If disk usage > 90%
- **Network device down**: If SNMP unreachable

### 3. Create User Groups
- **Network admins**: Receive all alerts
- **System admins**: Receive host alerts only

## Maintenance Tasks

### Database Backup
Automatic daily backups are configured:
```bash
# Backup location
/var/lib/zabbix/backups/

# Manual backup
ssh dex5550 "systemctl start zabbix-backup"
```

### Log Management
Automatic log rotation is configured:
```bash
# Log locations
/var/log/zabbix/zabbix_server.log      # Server logs
/var/log/zabbix/zabbix_agent2.log      # Agent logs (each host)
```

### Performance Monitoring
Monitor Zabbix performance via Grafana:
- Server queue size
- Cache utilization
- Database performance

## Troubleshooting

### Zabbix Server Issues
```bash
# Check server status
ssh dex5550 "systemctl status zabbix-server"

# Check server logs
ssh dex5550 "journalctl -u zabbix-server -f"

# Check database
ssh dex5550 "sqlite3 /var/lib/zabbix/zabbix.db '.tables'"
```

### Agent Connection Issues
```bash
# Check agent status
ssh p620 "systemctl status zabbix-agent2"

# Test server connectivity
ssh p620 "telnet dex5550 10051"

# Check firewall
ssh dex5550 "ss -tlnp | grep 10051"
```

### SNMP Issues
```bash
# Test SNMP connectivity
snmpwalk -v2c -c public 192.168.1.1 1.3.6.1.2.1.1.1.0

# Check device accessibility
ping 192.168.1.1

# Verify community string
snmpwalk -v2c -c public 192.168.1.1 sysDescr
```

### Web Interface Issues
```bash
# Check web service
ssh dex5550 "systemctl status zabbix-web"

# Check Traefik routing
ssh dex5550 "curl -I http://127.0.0.1:8080"

# Check SSL certificate
curl -I https://home.freundcloud.com/zabbix
```

## Security Considerations

### 1. Change Default Passwords
- Zabbix Admin user password
- Traefik basic auth password

### 2. SNMP Community Strings
- Consider using SNMPv3 for better security
- Change from "public" to custom community strings

### 3. Network Security
- Zabbix agent port (10050) is open on all hosts
- SNMP port (161) should be restricted to monitoring server

### 4. Database Security
- SQLite database is local to DEX5550
- Regular backups to prevent data loss
- Consider encryption for sensitive environments

## Performance Optimization

### Server Performance
- SQLite is suitable for < 1000 monitored hosts
- Current setup monitors 4 hosts + network devices
- Cache settings optimized for small installation

### Agent Performance  
- Lightweight Zabbix Agent 2 
- Minimal resource usage
- Configurable check intervals

### Network Impact
- SNMP polling every 60 seconds (default)
- Agent data collection every 60 seconds
- Compressed data transfer

## Future Enhancements

### Planned Improvements
1. **Custom templates** for NixOS-specific monitoring
2. **Integration with Tailscale** for remote monitoring
3. **Automated device discovery** for network devices
4. **Advanced alerting** with escalation rules
5. **Mobile notifications** via Telegram/Slack

### Scaling Considerations
- Switch to PostgreSQL if monitoring > 100 hosts
- Add Zabbix proxy for remote locations
- Implement high availability with clustering

This completes the comprehensive Zabbix monitoring setup for your NixOS infrastructure!