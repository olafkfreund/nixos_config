# NZBGet Grafana Dashboard Configuration
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.monitoring.nzbgetDashboard;
in
{
  options.monitoring.nzbgetDashboard = {
    enable = mkEnableOption "Enable NZBGet Grafana dashboard";

    grafanaUrl = mkOption {
      type = types.str;
      default = "http://localhost:3001";
      description = "Grafana server URL";
    };
  };

  config = mkIf cfg.enable {
    # NZBGet Dashboard Provisioning Service
    systemd.services.nzbget-dashboard-provisioner = {
      description = "NZBGet Dashboard Provisioner";
      after = [ "grafana.service" ];
      wants = [ "grafana.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "nzbget-dashboard-provisioner" ''
                    #!/bin/bash

                    DASHBOARD_DIR="/var/lib/grafana/dashboards"
                    mkdir -p "$DASHBOARD_DIR"

                    echo "[$(date)] Provisioning NZBGet dashboard..."

                    # Create comprehensive NZBGet dashboard
                    cat > "$DASHBOARD_DIR/nzbget-monitoring.json" << 'EOF'
          {
            "id": null,
            "title": "NZBGet Monitoring",
              "tags": ["nzbget", "downloads", "media"],
              "timezone": "browser",
              "panels": [
                {
                  "id": 1,
                  "title": "NZBGet Status",
                  "type": "stat",
                  "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
                  "targets": [
                    {
                      "expr": "nzbget_up",
                      "legendFormat": "Status",
                      "refId": "A"
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
                  "id": 2,
                  "title": "Current Download Speed",
                  "type": "stat",
                  "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
                  "targets": [
                    {
                      "expr": "nzbget_download_rate_kbps",
                      "legendFormat": "KB/s",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "unit": "KBs",
                      "color": {"mode": "palette-classic"},
                      "thresholds": {
                        "steps": [
                          {"color": "red", "value": 0},
                          {"color": "yellow", "value": 100},
                          {"color": "green", "value": 1000}
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 3,
                  "title": "Queue Size",
                  "type": "stat",
                  "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
                  "targets": [
                    {
                      "expr": "nzbget_queue_count",
                      "legendFormat": "Items",
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
                  "title": "Download Status",
                  "type": "stat",
                  "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
                  "targets": [
                    {
                      "expr": "nzbget_download_paused",
                      "legendFormat": "Paused",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": {"mode": "thresholds"},
                      "thresholds": {
                        "steps": [
                          {"color": "green", "value": 0},
                          {"color": "red", "value": 1}
                        ]
                      },
                      "mappings": [
                        {"options": {"0": {"text": "ACTIVE"}, "1": {"text": "PAUSED"}}, "type": "value"}
                      ]
                    }
                  }
                },
                {
                  "id": 5,
                  "title": "Download Speed Over Time",
                  "type": "timeseries",
                  "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
                  "targets": [
                    {
                      "expr": "nzbget_download_rate_kbps",
                      "legendFormat": "Download Speed (KB/s)",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "unit": "KBs",
                      "color": {"mode": "palette-classic"}
                    }
                  }
                },
                {
                  "id": 6,
                  "title": "Queue Statistics",
                  "type": "timeseries",
                  "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
                  "targets": [
                    {
                      "expr": "nzbget_queue_count",
                      "legendFormat": "Queue Items",
                      "refId": "A"
                    },
                    {
                      "expr": "nzbget_queue_remaining_size_mb / 1024",
                      "legendFormat": "Remaining (GB)",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": {"mode": "palette-classic"}
                    }
                  }
                },
                {
                  "id": 7,
                  "title": "Download Completion Stats",
                  "type": "stat",
                  "gridPos": {"h": 6, "w": 8, "x": 0, "y": 12},
                  "targets": [
                    {
                      "expr": "nzbget_completed_count",
                      "legendFormat": "Completed",
                      "refId": "A"
                    },
                    {
                      "expr": "nzbget_failed_count",
                      "legendFormat": "Failed",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": {"mode": "palette-classic"},
                      "unit": "short"
                    }
                  }
                },
                {
                  "id": 8,
                  "title": "Data Transfer",
                  "type": "stat",
                  "gridPos": {"h": 6, "w": 8, "x": 8, "y": 12},
                  "targets": [
                    {
                      "expr": "nzbget_total_downloaded_mb / 1024",
                      "legendFormat": "Total Downloaded (GB)",
                      "refId": "A"
                    },
                    {
                      "expr": "nzbget_remaining_size_mb / 1024",
                      "legendFormat": "Remaining (GB)",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "unit": "bytes",
                      "color": {"mode": "palette-classic"}
                    }
                  }
                },
                {
                  "id": 9,
                  "title": "System Status",
                  "type": "stat",
                  "gridPos": {"h": 6, "w": 8, "x": 16, "y": 12},
                  "targets": [
                    {
                      "expr": "nzbget_uptime_seconds / 86400",
                      "legendFormat": "Uptime (days)",
                      "refId": "A"
                    },
                    {
                      "expr": "nzbget_thread_count",
                      "legendFormat": "Threads",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": {"mode": "palette-classic"}
                    }
                  }
                },
                {
                  "id": 10,
                  "title": "Success Rate",
                  "type": "piechart",
                  "gridPos": {"h": 8, "w": 12, "x": 0, "y": 18},
                  "targets": [
                    {
                      "expr": "nzbget_completed_count",
                      "legendFormat": "Completed",
                      "refId": "A"
                    },
                    {
                      "expr": "nzbget_failed_count",
                      "legendFormat": "Failed",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": {"mode": "palette-classic"},
                      "unit": "short"
                    }
                  }
                },
                {
                  "id": 11,
                  "title": "Download Progress",
                  "type": "bargauge",
                  "gridPos": {"h": 8, "w": 12, "x": 12, "y": 18},
                  "targets": [
                    {
                      "expr": "(nzbget_queue_total_size_mb - nzbget_queue_remaining_size_mb) / nzbget_queue_total_size_mb * 100",
                      "legendFormat": "Progress %",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "unit": "percent",
                      "min": 0,
                      "max": 100,
                      "color": {"mode": "continuous-GrYlRd"}
                    }
                  }
                },
                {
                  "id": 12,
                  "title": "Error Indicators",
                  "type": "stat",
                  "gridPos": {"h": 4, "w": 24, "x": 0, "y": 26},
                  "targets": [
                    {
                      "expr": "nzbget_server_standby",
                      "legendFormat": "Server Standby",
                      "refId": "A"
                    },
                    {
                      "expr": "nzbget_post_paused",
                      "legendFormat": "Post-Processing Paused",
                      "refId": "B"
                    },
                    {
                      "expr": "nzbget_quota_reached",
                      "legendFormat": "Quota Reached",
                      "refId": "C"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": {"mode": "thresholds"},
                      "thresholds": {
                        "steps": [
                          {"color": "green", "value": 0},
                          {"color": "red", "value": 1}
                        ]
                      },
                      "mappings": [
                        {"options": {"0": {"text": "OK"}, "1": {"text": "WARNING"}}, "type": "value"}
                      ]
                    }
                  }
                }
              ],
              "time": {"from": "now-6h", "to": "now"},
              "refresh": "30s",
              "schemaVersion": 39,
              "version": 1,
            "overwrite": true
          }
          EOF

                    echo "[$(date)] NZBGet dashboard provisioned successfully"
        '';
      };
    };

    # Create dashboard directory
    systemd.tmpfiles.rules = [
      "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    ];
  };
}
