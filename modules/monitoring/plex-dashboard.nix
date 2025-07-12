# Enhanced Plex Media Server Grafana Dashboard
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.monitoring.plexDashboard;
in {
  options.monitoring.plexDashboard = {
    enable = mkEnableOption "Enable comprehensive Plex Media Server dashboard";
    
    grafanaUrl = mkOption {
      type = types.str;
      default = "http://localhost:3001";
      description = "Grafana server URL";
    };
  };

  config = mkIf cfg.enable {
    # Plex Dashboard Provisioning Service
    systemd.services.plex-dashboard-provisioner = {
      description = "Plex Dashboard Provisioner";
      after = [ "grafana.service" ];
      wants = [ "grafana.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "plex-dashboard-provisioner" ''
          #!/bin/bash
          
          DASHBOARD_DIR="/var/lib/grafana/dashboards"
          mkdir -p "$DASHBOARD_DIR"
          
          echo "[$(date)] Provisioning comprehensive Plex Media Server dashboard..."
          
          # Create main Plex overview dashboard
          cat > "$DASHBOARD_DIR/plex-overview.json" << 'EOF'
{
  "id": null,
  "title": "🎬 Plex Media Server - Overview",
    "tags": ["plex", "media", "streaming"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🟢 Server Status",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "plex_exporter_up",
            "legendFormat": "Server",
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
              {"options": {"0": {"text": "DOWN"}, "1": {"text": "ONLINE"}}, "type": "value"}
            ]
          }
        }
      },
      {
        "id": 2,
        "title": "👥 Active Streams",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 4, "y": 0},
        "targets": [
          {
            "expr": "plex_current_streams",
            "legendFormat": "Streams",
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
                {"color": "yellow", "value": 5},
                {"color": "red", "value": 10}
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "🔄 Transcoding",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 8, "y": 0},
        "targets": [
          {
            "expr": "plex_current_transcodes",
            "legendFormat": "Transcodes",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short",
            "color": {"mode": "thresholds"},
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 2},
                {"color": "red", "value": 4}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "⚡ Direct Play",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "plex_current_direct_plays",
            "legendFormat": "Direct",
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
        "title": "📡 Total Bandwidth",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 16, "y": 0},
        "targets": [
          {
            "expr": "plex_total_bandwidth_kbps / 1024",
            "legendFormat": "Mbps",
            "refId": "A"
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
        "id": 6,
        "title": "🌐 WAN vs LAN Usage",
        "type": "stat",
        "gridPos": {"h": 4, "w": 4, "x": 20, "y": 0},
        "targets": [
          {
            "expr": "plex_wan_bandwidth_kbps / 1024",
            "legendFormat": "WAN",
            "refId": "A"
          },
          {
            "expr": "plex_lan_bandwidth_kbps / 1024",
            "legendFormat": "LAN",
            "refId": "B"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Mbps",
            "color": {"mode": "palette-classic"},
            "decimals": 1
          }
        }
      },
      {
        "id": 7,
        "title": "📈 Stream Activity Over Time",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
        "targets": [
          {
            "expr": "plex_current_streams",
            "legendFormat": "Total Streams",
            "refId": "A"
          },
          {
            "expr": "plex_current_transcodes",
            "legendFormat": "Transcoding",
            "refId": "B"
          },
          {
            "expr": "plex_current_direct_plays",
            "legendFormat": "Direct Play",
            "refId": "C"
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
        "title": "📊 Bandwidth Usage Over Time",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
        "targets": [
          {
            "expr": "plex_total_bandwidth_kbps / 1024",
            "legendFormat": "Total Bandwidth",
            "refId": "A"
          },
          {
            "expr": "plex_wan_bandwidth_kbps / 1024",
            "legendFormat": "WAN Bandwidth",
            "refId": "B"
          },
          {
            "expr": "plex_lan_bandwidth_kbps / 1024",
            "legendFormat": "LAN Bandwidth",
            "refId": "C"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "Mbps",
            "color": {"mode": "palette-classic"}
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

          # Create Top Content dashboard
          cat > "$DASHBOARD_DIR/plex-top-content.json" << 'EOF'
{
  "id": null,
  "title": "🏆 Plex - Top Content & Users",
    "tags": ["plex", "analytics", "top"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🎬 Top Movies (Last 30 Days)",
        "type": "barchart",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "topk(10, plex_top_movies_plays)",
            "legendFormat": "{{title}} ({{year}})",
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
          "orientation": "horizontal",
          "barWidth": 0.6,
          "groupWidth": 0.7
        }
      },
      {
        "id": 2,
        "title": "📺 Top TV Shows (Last 30 Days)",
        "type": "barchart",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "topk(10, plex_top_shows_plays)",
            "legendFormat": "{{title}} ({{year}})",
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
          "orientation": "horizontal",
          "barWidth": 0.6,
          "groupWidth": 0.7
        }
      },
      {
        "id": 3,
        "title": "👤 Top Users by Plays",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 8, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "plex_top_users_plays",
            "legendFormat": "{{user}}",
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
        "title": "⏱️ Top Users by Watch Time",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 8, "x": 8, "y": 8},
        "targets": [
          {
            "expr": "plex_top_users_duration_hours",
            "legendFormat": "{{user}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "h",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 5,
        "title": "📈 User Activity Ranking",
        "type": "barchart",
        "gridPos": {"h": 8, "w": 8, "x": 16, "y": 8},
        "targets": [
          {
            "expr": "plex_top_users_duration_hours",
            "legendFormat": "{{user}}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "h",
            "color": {"mode": "continuous-BlPu"}
          }
        },
        "options": {
          "orientation": "horizontal"
        }
      }
    ],
    "time": {"from": "now-30d", "to": "now"},
    "refresh": "5m",
    "schemaVersion": 39,
    "version": 1,
  "overwrite": true
}
EOF

          # Create Geographic & Platform Analytics dashboard
          cat > "$DASHBOARD_DIR/plex-analytics.json" << 'EOF'
{
  "id": null,
  "title": "🌍 Plex - Geographic & Platform Analytics",
    "tags": ["plex", "analytics", "geographic"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "🌎 Streams by Location",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 8, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "sum by (location) (plex_plays_by_location)",
            "legendFormat": "{{location}}",
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
        "id": 2,
        "title": "📱 Streams by Platform",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 8, "x": 8, "y": 0},
        "targets": [
          {
            "expr": "sum by (platform) (plex_plays_by_platform)",
            "legendFormat": "{{platform}}",
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
        "id": 3,
        "title": "🖥️ Player Applications",
        "type": "barchart",
        "gridPos": {"h": 8, "w": 8, "x": 16, "y": 0},
        "targets": [
          {
            "expr": "sum by (player) (plex_plays_by_platform)",
            "legendFormat": "{{player}}",
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
        "id": 4,
        "title": "🔗 Unique IP Addresses",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "count(plex_unique_ips)",
            "legendFormat": "Unique IPs",
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
        "title": "📊 Stream Quality Distribution",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 9, "x": 6, "y": 8},
        "targets": [
          {
            "expr": "sum by (resolution) (plex_resolution_plays)",
            "legendFormat": "{{resolution}}",
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
        "id": 6,
        "title": "🎭 Stream Type Distribution",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 9, "x": 15, "y": 8},
        "targets": [
          {
            "expr": "sum by (type) (plex_stream_type_count)",
            "legendFormat": "{{type}}",
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
    "time": {"from": "now-30d", "to": "now"},
    "refresh": "5m",
    "schemaVersion": 39,
    "version": 1,
  "overwrite": true
}
EOF

          # Create Library Statistics dashboard
          cat > "$DASHBOARD_DIR/plex-library-stats.json" << 'EOF'
{
  "id": null,
  "title": "📚 Plex - Library Statistics",
    "tags": ["plex", "library", "statistics"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "📦 Library Content Count",
        "type": "barchart",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "plex_library_count",
            "legendFormat": "{{library}} ({{type}})",
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
        "id": 2,
        "title": "📈 Daily Watch Time (Hours)",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "plex_daily_watch_hours",
            "legendFormat": "Watch Hours",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "h",
            "color": {"mode": "palette-classic"}
          }
        }
      },
      {
        "id": 3,
        "title": "🎯 Daily Play Count",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "plex_daily_plays",
            "legendFormat": "Daily Plays",
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
        "id": 4,
        "title": "📊 Content Type Distribution",
        "type": "piechart",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "sum by (type) (plex_library_count)",
            "legendFormat": "{{type}}",
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
    "time": {"from": "now-30d", "to": "now"},
    "refresh": "5m",
    "schemaVersion": 39,
    "version": 1,
  "overwrite": true
}
EOF

          echo "[$(date)] Comprehensive Plex dashboards provisioned successfully"
        '';
      };
    };
    
    # Create dashboard directory
    systemd.tmpfiles.rules = [
      "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    ];
  };
}