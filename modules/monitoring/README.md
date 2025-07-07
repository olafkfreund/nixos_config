# 📊 NixOS Monitoring & Observability Stack

A comprehensive monitoring solution for multi-host NixOS environments with Prometheus, Grafana, and custom exporters.

## 🏗️ Architecture

### **Multi-Host Setup**
- **P620** (AMD/ROCm): Monitoring server running Prometheus + Grafana
- **Razer** (Intel/NVIDIA): Client host with exporters
- **P510** (Xeon/NVIDIA): Client host with exporters  
- **DEX5550** (Intel SFF): Client host with exporters

### **Service Stack**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Grafana   │    │ Prometheus  │    │ Alertmanager│
│   :3000     │    │   :9090     │    │   :9093     │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
       ┌───────────────────┼───────────────────┐
       │                   │                   │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│Node Exporter│    │NixOS Export │    │Systemd Exp. │
│   :9100     │    │   :9101     │    │   :9102     │
└─────────────┘    └─────────────┘    └─────────────┘
```

## 🚀 Quick Start

### **Enable Monitoring**

#### **Server Configuration (P620)**
```nix
monitoring = {
  enable = true;
  mode = "server";
  serverHost = "p620";
  retention = "90d";
  
  features = {
    prometheus = true;
    grafana = true;
    nodeExporter = true;
    nixosMetrics = true;
    alerting = true;
  };
};
```

#### **Client Configuration (Other Hosts)**
```nix
monitoring = {
  enable = true;
  mode = "client";
  serverHost = "p620";
  
  features = {
    nodeExporter = true;
    nixosMetrics = true;
    alerting = false;
  };
};
```

### **Access Dashboards**

After deployment:
- **Grafana**: http://p620:3000 (admin/nixos-admin)
- **Prometheus**: http://p620:9090
- **Alertmanager**: http://p620:9093

## 📊 Metrics Collection

### **System Metrics (Node Exporter)**
- **Hardware**: CPU, memory, disk, network, temperature
- **System**: Load averages, processes, file systems
- **Network**: Interface statistics, connections
- **Storage**: Disk I/O, filesystem usage

### **NixOS-Specific Metrics (Custom Exporter)**
- **Nix Store**: Size, derivation count, garbage collection stats
- **Generations**: Current generation, total count
- **System**: Last rebuild time, channel information
- **Boot**: systemd-boot entries, configuration status

### **Service Metrics (Systemd Exporter)**
- **Units**: Total, active, failed service counts
- **States**: Per-service state tracking
- **System**: Overall system health status

### **Application Metrics**
- **AI Services**: Ollama usage, provider metrics
- **Development**: Build times, tool usage
- **Desktop**: Application performance

## 📋 Pre-configured Dashboards

### **System Overview Dashboard**
- Multi-host system summary
- Resource utilization trends
- Network topology view
- Alert status overview

### **Host-Specific Dashboards**
- **P620**: AMD/ROCm performance, AI workloads
- **Razer**: Battery life, thermal management
- **P510**: Server workloads, CUDA usage
- **DEX5550**: Efficiency metrics

### **NixOS Dashboard**
- Generation management
- Nix store optimization
- Build performance
- Configuration drift

## 🔧 Management Commands

### **Status Commands**
```bash
# Overall monitoring status
prometheus-status
grafana-status
alert-status
node-exporter-status

# Service health
systemctl status prometheus
systemctl status grafana
systemctl status alertmanager
```

### **Configuration Management**
```bash
# Reload Prometheus config
prometheus-reload

# View Grafana dashboards
grafana-dashboards

# Check alert logs
alert-logs

# Test alerting
test-alert
```

### **Metrics Exploration**
```bash
# Query Prometheus directly
curl "http://p620:9090/api/v1/query?query=up"

# Check node exporter metrics
curl "http://localhost:9100/metrics"

# NixOS-specific metrics
curl "http://localhost:9101/metrics"
```

## 🚨 Alerting Rules

### **System Alerts**
- **HighCPUUsage**: CPU > 80% for 5+ minutes
- **HighMemoryUsage**: Memory > 90% for 5+ minutes  
- **LowDiskSpace**: Disk > 85% for 10+ minutes
- **HostDown**: Host unreachable for 1+ minute

### **NixOS Alerts**
- **NixStoreSize**: Nix store > 50GB for 1+ hour
- **SystemdServiceFailed**: Any systemd service failed

### **Network Alerts**
- **HighNetworkTraffic**: Network > 100MB/s for 10+ minutes

### **Alert Routing**
- **Critical**: Immediate notification, 5-minute repeat
- **Warning**: Standard notification, 30-minute repeat
- **Info**: Log only, no notifications

## 📊 Metric Examples

### **Query Examples**

#### **System Performance**
```promql
# CPU usage per host
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage per mount
(1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100
```

#### **NixOS Metrics**
```promql
# Nix store size trend
nixos_store_size_bytes

# Generation count per host
nixos_generations_total

# Failed systemd services
systemd_units_failed
```

#### **Network Health**
```promql
# Inter-host connectivity
up{job="node-exporter"}

# Network throughput
rate(node_network_receive_bytes_total[5m])
```

## 🔍 Troubleshooting

### **Common Issues**

#### **Prometheus Not Scraping**
```bash
# Check target status
curl "http://p620:9090/api/v1/targets"

# Verify firewall
nmap -p 9100 target-host

# Check exporter
systemctl status prometheus-node-exporter
```

#### **Grafana Connection Issues**
```bash
# Verify Grafana service
systemctl status grafana

# Check data source
curl -u admin:nixos-admin "http://p620:3000/api/datasources"

# Test Prometheus connection
curl "http://p620:9090/api/v1/label/__name__/values"
```

#### **Missing Metrics**
```bash
# Check exporter logs
journalctl -u nixos-exporter -f
journalctl -u systemd-exporter -f

# Verify metric endpoints
curl "http://localhost:9101/metrics" | grep nixos
curl "http://localhost:9102/metrics" | grep systemd
```

### **Performance Optimization**

#### **Reduce Scrape Load**
```nix
monitoring = {
  scrapeInterval = "30s";  # Increase interval
  retention = "30d";       # Reduce retention
};
```

#### **Selective Monitoring**
```nix
monitoring.features = {
  nodeExporter = true;
  nixosMetrics = false;    # Disable if not needed
  alerting = false;        # Client hosts only
};
```

## 📈 Dashboard Customization

### **Adding Custom Panels**

1. **Access Grafana**: http://p620:3000
2. **Login**: admin/nixos-admin
3. **Create Panel**: + → Add Panel
4. **Query Metrics**: Use Prometheus data source
5. **Save Dashboard**: Ctrl+S

### **Custom Metrics**

Add custom exporters in host configurations:
```nix
# Custom application metrics
systemd.services.my-app-exporter = {
  description = "Custom application metrics";
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    ExecStart = "${pkgs.my-exporter}/bin/my-exporter";
    User = "monitoring";
  };
};

# Add to Prometheus scrape config
services.prometheus.scrapeConfigs = [{
  job_name = "my-app";
  static_configs = [{
    targets = [ "localhost:8080" ];
  }];
}];
```

## 🔒 Security Considerations

### **Network Security**
- Monitoring services bound to all interfaces for multi-host access
- Firewall rules restrict access to monitoring ports
- Consider VPN (Tailscale) for secure remote access

### **Authentication**
- Grafana requires login (admin/nixos-admin)
- Prometheus and Alertmanager currently no auth (internal network)
- Consider adding reverse proxy with authentication for production

### **Data Privacy**
- Metrics may contain sensitive system information
- Consider data retention policies
- Regular security audits of exposed metrics

## 🔄 Backup & Recovery

### **Configuration Backup**
All monitoring configuration is in git-tracked NixOS config.

### **Data Backup**
```bash
# Backup Prometheus data
tar -czf prometheus-backup.tar.gz /var/lib/prometheus/

# Backup Grafana dashboards
curl -u admin:nixos-admin "http://p620:3000/api/search" | jq '.[].uri'
```

### **Disaster Recovery**
1. Restore NixOS configuration
2. Deploy with `just p620`
3. Restore data from backups if needed
4. Dashboards recreated automatically from config

## 📚 Related Documentation

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [NixOS Monitoring Guide](https://nixos.wiki/wiki/Prometheus)
- [Feature Flags](../common/features.nix)
- [Host Configurations](../../hosts/)

## 🎯 Next Steps

1. **Deploy** to P620: `just p620`
2. **Configure clients**: Update other host configs
3. **Access dashboards**: http://p620:3000
4. **Customize alerts**: Modify alerting rules
5. **Add custom metrics**: Extend exporters as needed

The monitoring stack provides comprehensive visibility into your NixOS infrastructure with minimal configuration! 📊