# Beautiful Network Activity Dashboards Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.monitoring.networkDashboards;
in {
  options.monitoring.networkDashboards = {
    enable = mkEnableOption "Enable beautiful network activity dashboards";
    
    grafanaUrl = mkOption {
      type = types.str;
      default = "http://localhost:3001";
      description = "Grafana server URL";
    };
  };

  config = mkIf cfg.enable {
    # Network Dashboards Provisioning Service
    systemd.services.network-dashboards-provisioner = {
      description = "Network Activity Dashboards Provisioner";
      after = [ "grafana.service" ];
      wants = [ "grafana.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "network-dashboards-provisioner" ''
          #!/bin/bash
          
          DASHBOARD_DIR="/var/lib/grafana/dashboards"
          mkdir -p "$DASHBOARD_DIR"
          
          echo "[$(date)] Provisioning beautiful network activity dashboards..."
          
          # Create Network Overview Dashboard
          cat > "$DASHBOARD_DIR/network-overview.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "🌐 Network Overview - Real-Time Activity",
    "tags": ["network", "overview", "activity"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🌍 Network Status",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "network_discovery_last_scan_timestamp > (time() - 300)",
            "legendFormat": "Discovery",
            "refId": "A"
          },
          {
            "expr": "network_traffic_analyzer_up",
            "legendFormat": "Traffic Analysis",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "thresholds"},
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"options": {"0": {"text": "DOWN"}, "1": {"text": "ONLINE"}}, "type": "value"}
            ]
          }
        }
      },
      {
        "id": 2,
        "title": "📱 Active Devices",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 4, "y": 0},
        "targets": [
          {
            "expr": "network_devices_active",
            "legendFormat": "Active",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"},
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 10},
                {"color": "red", "value": 20}
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "📊 Total Bandwidth",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 8, "y": 0},
        "targets": [
          {
            "expr": "rate(network_traffic_bytes_total{direction=\"rx\"}[5m]) * 8 / 1024 / 1024",
            "legendFormat": "Download",
            "refId": "A"
          },
          {
            "expr": "rate(network_traffic_bytes_total{direction=\"tx\"}[5m]) * 8 / 1024 / 1024",
            "legendFormat": "Upload",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Mbps",
            "color": {"mode": "continuous-GrYlRd"},
            "decimals": 1
          }
        }
      },
      {
        "id": 4,
        "title": "🔗 Active Connections",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "network_active_connections{type=\"total\"}",
            "legendFormat": "Total",
            "refId": "A"
          },
          {
            "expr": "network_active_connections{type=\"external\"}",
            "legendFormat": "External",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 5,
        "title": "📈 Network Traffic Over Time",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
        "targets": [
          {
            "expr": "rate(network_traffic_bytes_total{direction=\"rx\"}[1m]) * 8 / 1024 / 1024",
            "legendFormat": "Download (Mbps)",
            "refId": "A"
          },
          {
            "expr": "rate(network_traffic_bytes_total{direction=\"tx\"}[1m]) * 8 / 1024 / 1024",
            "legendFormat": "Upload (Mbps)",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Mbps",
            "color": {"mode": "palette-classic"},
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "smooth",
              "fillOpacity": 20
            }
          }
        }
      },
      {
        "id": 6,
        "title": "🎯 Protocol Distribution",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 4},
        "targets": [
          {
            "expr": "network_protocol_packets",
            "legendFormat": "{{protocol}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 7,
        "title": "🌍 Traffic by Country",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 4},
        "targets": [
          {
            "expr": "network_connections_by_country",
            "legendFormat": "{{country}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "30s",
    "schemaVersion": 39,
    "version": 1
  },
  "overwrite": true
}
EOF

          # Create Device Activity Dashboard
          cat > "$DASHBOARD_DIR/network-devices.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "📱 Network Devices - Activity & Classification",
    "tags": ["network", "devices", "activity"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🏠 Device Discovery Map",
        "type": "table",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "network_device_info",
            "legendFormat": "",
            "refId": "A",
            "format": "table"
          }
        ],
        "transformations": [
          {
            "id": "organize",
            "options": {
              "excludeByName": {"Time": true, "Value": true},
              "indexByName": {},
              "renameByName": {
                "ip": "IP Address",
                "mac": "MAC Address", 
                "hostname": "Hostname",
                "vendor": "Vendor",
                "type": "Device Type"
              }
            }
          }
        ],
        "fieldConfig": {
          "defaults": {
            "custom": {
              "displayMode": "color-background"
            }
          }
        }
      },
      {
        "id": 2,
        "title": "📊 Devices by Type",
        "type": "barchart",
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "network_devices_by_type",
            "legendFormat": "{{type}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        },
        "options": {
          "orientation": "horizontal"
        }
      },
      {
        "id": 3,
        "title": "🏭 Devices by Vendor",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
        "targets": [
          {
            "expr": "topk(8, network_devices_by_vendor)",
            "legendFormat": "{{vendor}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 4,
        "title": "⏱️ Device Discovery Timeline",
        "type": "timeseries",
        "gridPos": {"h": 6, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "network_devices_total",
            "legendFormat": "Total Devices",
            "refId": "A"
          },
          {
            "expr": "network_devices_active",
            "legendFormat": "Active Devices",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 5,
        "title": "🔍 Device Classification Stats",
        "type": "stat",
        "gridPos": {"h": 6, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "network_devices_by_type{type=\"nixos-host\"}",
            "legendFormat": "NixOS Hosts",
            "refId": "A"
          },
          {
            "expr": "network_devices_by_type{type=\"mobile\"}",
            "legendFormat": "Mobile Devices",
            "refId": "B"
          },
          {
            "expr": "network_devices_by_type{type=\"media\"}",
            "legendFormat": "Media Devices",
            "refId": "C"
          },
          {
            "expr": "network_devices_by_type{type=\"unknown\"}",
            "legendFormat": "Unknown",
            "refId": "D"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      }
    ],
    "time": {"from": "now-6h", "to": "now"},
    "refresh": "1m",
    "schemaVersion": 39,
    "version": 1
  },
  "overwrite": true
}
EOF

          # Create Traffic Analysis Dashboard
          cat > "$DASHBOARD_DIR/network-traffic-analysis.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "🚦 Network Traffic Analysis - Deep Insights",
    "tags": ["network", "traffic", "analysis", "protocols"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🔄 Real-Time Bandwidth Usage",
        "type": "timeseries",
        "gridPos": {"h": 6, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "rate(network_traffic_bytes_total{direction=\"rx\"}[1m]) * 8 / 1024 / 1024",
            "legendFormat": "Download",
            "refId": "A"
          },
          {
            "expr": "rate(network_traffic_bytes_total{direction=\"tx\"}[1m]) * 8 / 1024 / 1024",
            "legendFormat": "Upload",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Mbps",
            "color": {"mode": "palette-classic"},
            "custom": {
              "drawStyle": "line",
              "lineInterpolation": "smooth",
              "fillOpacity": 30,
              "gradientMode": "opacity"
            }
          }
        }
      },
      {
        "id": 2,
        "title": "📊 Bandwidth Gauge",
        "type": "gauge",
        "gridPos": {"h": 6, "w": 6, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "(rate(network_traffic_bytes_total{direction=\"rx\"}[1m]) + rate(network_traffic_bytes_total{direction=\"tx\"}[1m])) * 8 / 1024 / 1024",
            "legendFormat": "Total",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Mbps",
            "min": 0,
            "max": 100,
            "color": {"mode": "continuous-GrYlRd"},
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 50},
                {"color": "red", "value": 80}
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "📈 Traffic Volume",
        "type": "stat",
        "gridPos": {"h": 6, "w": 6, "x": 18, "y": 0},
        "targets": [
          {
            "expr": "network_traffic_bytes_total{direction=\"rx\"} / 1024 / 1024 / 1024",
            "legendFormat": "Downloaded (GB)",
            "refId": "A"
          },
          {
            "expr": "network_traffic_bytes_total{direction=\"tx\"} / 1024 / 1024 / 1024",
            "legendFormat": "Uploaded (GB)",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "decgbytes",
            "decimals": 2,
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 4,
        "title": "🌐 Protocol Analysis",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 8, "x": 0, "y": 6},
        "targets": [
          {
            "expr": "network_protocol_packets",
            "legendFormat": "{{protocol}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 5,
        "title": "🎯 Service Connections",
        "type": "barchart",
        "gridPos": {"h": 8, "w": 8, "x": 8, "y": 6},
        "targets": [
          {
            "expr": "network_service_connections",
            "legendFormat": "{{service}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        },
        "options": {
          "orientation": "horizontal"
        }
      },
      {
        "id": 6,
        "title": "🌍 Geographic Distribution",
        "type": "worldmap",
        "gridPos": {"h": 8, "w": 8, "x": 16, "y": 6},
        "targets": [
          {
            "expr": "network_connections_by_country",
            "legendFormat": "{{country}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "continuous-GrYlRd"}
          }
        }
      },
      {
        "id": 7,
        "title": "📊 Connection Flow Analysis",
        "type": "timeseries",
        "gridPos": {"h": 6, "w": 12, "x": 0, "y": 14},
        "targets": [
          {
            "expr": "network_active_connections{type=\"total\"}",
            "legendFormat": "Total Connections",
            "refId": "A"
          },
          {
            "expr": "network_active_connections{type=\"external\"}",
            "legendFormat": "External Connections",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 8,
        "title": "⚡ Traffic Rate Indicators",
        "type": "stat",
        "gridPos": {"h": 6, "w": 12, "x": 12, "y": 14},
        "targets": [
          {
            "expr": "rate(network_traffic_packets_total{direction=\"rx\"}[1m])",
            "legendFormat": "RX Packets/sec",
            "refId": "A"
          },
          {
            "expr": "rate(network_traffic_packets_total{direction=\"tx\"}[1m])",
            "legendFormat": "TX Packets/sec",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "pps",
            "color": {"mode": "continuous-BlPu"}
          }
        }
      }
    ],
    "time": {"from": "now-3h", "to": "now"},
    "refresh": "15s",
    "schemaVersion": 39,
    "version": 1
  },
  "overwrite": true
}
EOF

          # Create Network Performance Dashboard
          cat > "$DASHBOARD_DIR/network-performance.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "⚡ Network Performance & Health",
    "tags": ["network", "performance", "health", "monitoring"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🚀 Network Performance Score",
        "type": "gauge",
        "gridPos": {"h": 6, "w": 6, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "100 - (rate(network_traffic_bytes_total{direction=\"rx\"}[5m]) * 8 / 1024 / 1024 / 100 * 100)",
            "legendFormat": "Performance %",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "color": {"mode": "continuous-GrYlRd"},
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 60},
                {"color": "green", "value": 80}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "📡 Network Health Status",
        "type": "stat",
        "gridPos": {"h": 6, "w": 6, "x": 6, "y": 0},
        "targets": [
          {
            "expr": "network_discovery_last_scan_timestamp > (time() - 600)",
            "legendFormat": "Discovery",
            "refId": "A"
          },
          {
            "expr": "network_traffic_analyzer_up",
            "legendFormat": "Analysis",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "thresholds"},
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"options": {"0": {"text": "DOWN"}, "1": {"text": "UP"}}, "type": "value"}
            ]
          }
        }
      },
      {
        "id": 3,
        "title": "📊 Bandwidth Utilization",
        "type": "timeseries",
        "gridPos": {"h": 6, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "rate(network_traffic_bytes_total{direction=\"rx\"}[1m]) * 8 / 1024 / 1024",
            "legendFormat": "Download Utilization",
            "refId": "A"
          },
          {
            "expr": "rate(network_traffic_bytes_total{direction=\"tx\"}[1m]) * 8 / 1024 / 1024",
            "legendFormat": "Upload Utilization",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Mbps",
            "color": {"mode": "palette-classic"},
            "custom": {
              "fillOpacity": 25,
              "gradientMode": "hue"
            }
          }
        }
      },
      {
        "id": 4,
        "title": "🎯 Traffic Quality Metrics",
        "type": "stat",
        "gridPos": {"h": 4, "w": 8, "x": 0, "y": 6},
        "targets": [
          {
            "expr": "sum(network_protocol_packets{protocol=\"tcp\"}) / sum(network_protocol_packets) * 100",
            "legendFormat": "TCP %",
            "refId": "A"
          },
          {
            "expr": "sum(network_protocol_packets{protocol=\"udp\"}) / sum(network_protocol_packets) * 100",
            "legendFormat": "UDP %",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "decimals": 1,
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 5,
        "title": "🌐 External vs Internal Traffic",
        "type": "piechart",
        "gridPos": {"h": 4, "w": 8, "x": 8, "y": 6},
        "targets": [
          {
            "expr": "network_active_connections{type=\"external\"}",
            "legendFormat": "External",
            "refId": "A"
          },
          {
            "expr": "network_active_connections{type=\"total\"} - network_active_connections{type=\"external\"}",
            "legendFormat": "Internal",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 6,
        "title": "📈 Network Activity Heatmap",
        "type": "heatmap",
        "gridPos": {"h": 4, "w": 8, "x": 16, "y": 6},
        "targets": [
          {
            "expr": "rate(network_traffic_bytes_total[1m])",
            "legendFormat": "{{direction}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Bps",
            "color": {"mode": "continuous-GrYlRd"}
          }
        }
      }
    ],
    "time": {"from": "now-2h", "to": "now"},
    "refresh": "30s",
    "schemaVersion": 39,
    "version": 1
  },
  "overwrite": true
}
EOF

          echo "[$(date)] Beautiful network activity dashboards provisioned successfully"
        '';
      };
    };
    
    # Create dashboard directory
    systemd.tmpfiles.rules = [
      "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    ];
  };
}