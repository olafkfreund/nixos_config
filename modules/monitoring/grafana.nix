{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.monitoring;
  
  # Pre-configured NixOS dashboard
  nixosDashboard = pkgs.writeText "nixos-dashboard.json" (builtins.toJSON {
    id = null;
    title = "NixOS System Overview";
    tags = ["nixos" "system"];
    timezone = "browser";
      panels = [
        {
          id = 1;
          title = "System Load";
          type = "stat";
          targets = [{
            expr = "node_load1";
            legendFormat = "1m load";
          }];
          gridPos = { h = 8; w = 6; x = 0; y = 0; };
        }
        {
          id = 2;
          title = "Memory Usage";
          type = "stat";
          targets = [{
            expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
            legendFormat = "Memory %";
          }];
          gridPos = { h = 8; w = 6; x = 6; y = 0; };
        }
        {
          id = 3;
          title = "CPU Usage";
          type = "timeseries";
          targets = [{
            expr = "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
            legendFormat = "{{instance}}";
          }];
          gridPos = { h = 8; w = 12; x = 0; y = 8; };
        }
        {
          id = 4;
          title = "Disk Usage";
          type = "bargauge";
          targets = [{
            expr = "(1 - (node_filesystem_avail_bytes{fstype!=\"tmpfs\"} / node_filesystem_size_bytes{fstype!=\"tmpfs\"})) * 100";
            legendFormat = "{{instance}} {{mountpoint}}";
          }];
          gridPos = { h = 8; w = 12; x = 12; y = 0; };
        }
        {
          id = 5;
          title = "Network Traffic";
          type = "timeseries";
          targets = [
            {
              expr = "rate(node_network_receive_bytes_total[5m])";
              legendFormat = "{{instance}} RX";
            }
            {
              expr = "rate(node_network_transmit_bytes_total[5m])";
              legendFormat = "{{instance}} TX";
            }
          ];
          gridPos = { h = 8; w = 12; x = 12; y = 8; };
        }
      ];
    time = {
      from = "now-1h";
      to = "now";
    };
    refresh = "30s";
  });

  # Host-specific dashboard generator
  hostDashboard = hostname: hardware: pkgs.writeText "${hostname}-dashboard.json" (builtins.toJSON {
    id = null;
    title = "${hostname} - ${hardware}";
    tags = ["nixos" "host" hostname];
    timezone = "browser";
    panels = [
      {
        id = 1;
        title = "${hostname} Status";
        type = "stat";
        targets = [{
          expr = "up{instance=\"${hostname}.home.freundcloud.com:9100\"}";
          legendFormat = "Status";
        }];
        gridPos = { h = 4; w = 6; x = 0; y = 0; };
        fieldConfig = {
          defaults = {
            mappings = [
              { options = { "0" = { text = "DOWN"; color = "red"; }; }; type = "value"; }
              { options = { "1" = { text = "UP"; color = "green"; }; }; type = "value"; }
            ];
          };
        };
      }
      {
        id = 2;
        title = "Uptime";
        type = "stat";
        targets = [{
          expr = "node_time_seconds{instance=\"${hostname}.home.freundcloud.com:9100\"} - node_boot_time_seconds{instance=\"${hostname}.home.freundcloud.com:9100\"}";
          legendFormat = "Uptime";
        }];
        gridPos = { h = 4; w = 6; x = 6; y = 0; };
        fieldConfig = {
          defaults = {
            unit = "s";
          };
        };
      }
      {
        id = 3;
        title = "CPU Usage";
        type = "timeseries";
        targets = [{
          expr = "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\",instance=\"${hostname}.home.freundcloud.com:9100\"}[5m])) * 100)";
          legendFormat = "CPU %";
        }];
        gridPos = { h = 8; w = 12; x = 0; y = 4; };
      }
      {
        id = 4;
        title = "Memory Usage";
        type = "timeseries";
        targets = [{
          expr = "(1 - (node_memory_MemAvailable_bytes{instance=\"${hostname}.home.freundcloud.com:9100\"} / node_memory_MemTotal_bytes{instance=\"${hostname}.home.freundcloud.com:9100\"})) * 100";
          legendFormat = "Memory %";
        }];
        gridPos = { h = 8; w = 12; x = 12; y = 4; };
      }
      {
        id = 5;
        title = "Disk Usage";
        type = "bargauge";
        targets = [{
          expr = "(1 - (node_filesystem_avail_bytes{fstype!=\"tmpfs\",instance=\"${hostname}.home.freundcloud.com:9100\"} / node_filesystem_size_bytes{fstype!=\"tmpfs\",instance=\"${hostname}.home.freundcloud.com:9100\"})) * 100";
          legendFormat = "{{mountpoint}}";
        }];
        gridPos = { h = 8; w = 24; x = 0; y = 12; };
      }
    ] ++ (if (hardware == "AMD") then [
      {
        id = 10;
        title = "AMD GPU Usage";
        type = "timeseries";
        targets = [{
          expr = "rocm_gpu_usage{instance=\"${hostname}.home.freundcloud.com:9100\"}";
          legendFormat = "GPU {{device}}";
        }];
        gridPos = { h = 8; w = 12; x = 0; y = 20; };
      }
    ] else if (hardware == "NVIDIA") then [
      {
        id = 11;
        title = "NVIDIA GPU Usage";
        type = "timeseries";
        targets = [{
          expr = "nvidia_gpu_utilization{instance=\"${hostname}.home.freundcloud.com:9100\"}";
          legendFormat = "GPU {{device}}";
        }];
        gridPos = { h = 8; w = 12; x = 0; y = 20; };
      }
    ] else []);
    time = {
      from = "now-6h";
      to = "now";
    };
    refresh = "30s";
  });

  # Media services dashboards
  plexDashboard = pkgs.writeText "plex-dashboard.json" (builtins.toJSON {
    id = null;
    title = "Plex Media Server";
    tags = ["media" "plex" "p510"];
    timezone = "browser";
    panels = [
      {
        id = 1;
        title = "Plex Service Status";
        type = "stat";
        targets = [{
          expr = "systemd_unit_state{name=\"plex.service\",instance=\"p510.home.freundcloud.com:9102\"}";
          legendFormat = "Service State";
        }];
        gridPos = { h = 4; w = 6; x = 0; y = 0; };
        fieldConfig = {
          defaults = {
            mappings = [
              { options = { "1" = { text = "ACTIVE"; color = "green"; }; }; type = "value"; }
              { options = { "0" = { text = "INACTIVE"; color = "red"; }; }; type = "value"; }
            ];
          };
        };
      }
      {
        id = 2;
        title = "Server CPU Usage";
        type = "timeseries";
        targets = [{
          expr = "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\",instance=\"p510.home.freundcloud.com:9100\"}[5m])) * 100)";
          legendFormat = "CPU %";
        }];
        gridPos = { h = 8; w = 12; x = 0; y = 4; };
      }
      {
        id = 3;
        title = "Server Memory Usage";
        type = "timeseries";
        targets = [{
          expr = "(1 - (node_memory_MemAvailable_bytes{instance=\"p510.home.freundcloud.com:9100\"} / node_memory_MemTotal_bytes{instance=\"p510.home.freundcloud.com:9100\"})) * 100";
          legendFormat = "Memory %";
        }];
        gridPos = { h = 8; w = 12; x = 12; y = 4; };
      }
      {
        id = 4;
        title = "Media Storage Usage";
        type = "bargauge";
        targets = [{
          expr = "(1 - (node_filesystem_avail_bytes{mountpoint=\"/mnt/media\",instance=\"p510.home.freundcloud.com:9100\"} / node_filesystem_size_bytes{mountpoint=\"/mnt/media\",instance=\"p510.home.freundcloud.com:9100\"})) * 100";
          legendFormat = "Media Storage";
        }];
        gridPos = { h = 6; w = 24; x = 0; y = 12; };
      }
    ];
    time = {
      from = "now-6h";
      to = "now";
    };
    refresh = "30s";
  });

  sonarrDashboard = pkgs.writeText "sonarr-dashboard.json" (builtins.toJSON {
    id = null;
    title = "Sonarr TV Shows";
    tags = ["media" "sonarr" "p510"];
    timezone = "browser";
    panels = [
      {
        id = 1;
        title = "Sonarr Service Status";
        type = "stat";
        targets = [{
          expr = "systemd_unit_state{name=\"sonarr.service\",instance=\"p510.home.freundcloud.com:9102\"}";
          legendFormat = "Service State";
        }];
        gridPos = { h = 4; w = 6; x = 0; y = 0; };
        fieldConfig = {
          defaults = {
            mappings = [
              { options = { "1" = { text = "ACTIVE"; color = "green"; }; }; type = "value"; }
              { options = { "0" = { text = "INACTIVE"; color = "red"; }; }; type = "value"; }
            ];
          };
        };
      }
      {
        id = 2;
        title = "Downloads Directory Usage";
        type = "stat";
        targets = [{
          expr = "node_filesystem_size_bytes{mountpoint=\"/mnt/media\",instance=\"p510.home.freundcloud.com:9100\"} - node_filesystem_avail_bytes{mountpoint=\"/mnt/media\",instance=\"p510.home.freundcloud.com:9100\"}";
          legendFormat = "Used Space";
        }];
        gridPos = { h = 4; w = 6; x = 6; y = 0; };
        fieldConfig = {
          defaults = {
            unit = "bytes";
          };
        };
      }
      {
        id = 3;
        title = "Network I/O";
        type = "timeseries";
        targets = [
          {
            expr = "rate(node_network_receive_bytes_total{device!=\"lo\",instance=\"p510.home.freundcloud.com:9100\"}[5m])";
            legendFormat = "Download";
          }
          {
            expr = "rate(node_network_transmit_bytes_total{device!=\"lo\",instance=\"p510.home.freundcloud.com:9100\"}[5m])";
            legendFormat = "Upload";
          }
        ];
        gridPos = { h = 8; w = 24; x = 0; y = 4; };
      }
    ];
    time = {
      from = "now-6h";
      to = "now";
    };
    refresh = "30s";
  });

  radarrDashboard = pkgs.writeText "radarr-dashboard.json" (builtins.toJSON {
    id = null;
    title = "Radarr Movies";
    tags = ["media" "radarr" "p510"];
    timezone = "browser";
    panels = [
      {
        id = 1;
        title = "Radarr Service Status";
        type = "stat";
        targets = [{
          expr = "systemd_unit_state{name=\"radarr.service\",instance=\"p510.home.freundcloud.com:9102\"}";
          legendFormat = "Service State";
        }];
        gridPos = { h = 4; w = 6; x = 0; y = 0; };
        fieldConfig = {
          defaults = {
            mappings = [
              { options = { "1" = { text = "ACTIVE"; color = "green"; }; }; type = "value"; }
              { options = { "0" = { text = "INACTIVE"; color = "red"; }; }; type = "value"; }
            ];
          };
        };
      }
      {
        id = 2;
        title = "Movie Storage Usage";
        type = "stat";
        targets = [{
          expr = "node_filesystem_size_bytes{mountpoint=\"/mnt/media\",instance=\"p510.home.freundcloud.com:9100\"} - node_filesystem_avail_bytes{mountpoint=\"/mnt/media\",instance=\"p510.home.freundcloud.com:9100\"}";
          legendFormat = "Used Space";
        }];
        gridPos = { h = 4; w = 6; x = 6; y = 0; };
        fieldConfig = {
          defaults = {
            unit = "bytes";
          };
        };
      }
      {
        id = 3;
        title = "Disk I/O";
        type = "timeseries";
        targets = [
          {
            expr = "rate(node_disk_read_bytes_total{instance=\"p510.home.freundcloud.com:9100\"}[5m])";
            legendFormat = "Read";
          }
          {
            expr = "rate(node_disk_written_bytes_total{instance=\"p510.home.freundcloud.com:9100\"}[5m])";
            legendFormat = "Write";
          }
        ];
        gridPos = { h = 8; w = 24; x = 0; y = 4; };
      }
    ];
    time = {
      from = "now-6h";
      to = "now";
    };
    refresh = "30s";
  });

  lidarrDashboard = pkgs.writeText "lidarr-dashboard.json" (builtins.toJSON {
    id = null;
    title = "Lidarr Music";
    tags = ["media" "lidarr" "p510"];
    timezone = "browser";
    panels = [
      {
        id = 1;
        title = "Lidarr Service Status";
        type = "stat";
        targets = [{
          expr = "systemd_unit_state{name=\"lidarr.service\",instance=\"p510.home.freundcloud.com:9102\"}";
          legendFormat = "Service State";
        }];
        gridPos = { h = 4; w = 6; x = 0; y = 0; };
        fieldConfig = {
          defaults = {
            mappings = [
              { options = { "1" = { text = "ACTIVE"; color = "green"; }; }; type = "value"; }
              { options = { "0" = { text = "INACTIVE"; color = "red"; }; }; type = "value"; }
            ];
          };
        };
      }
      {
        id = 2;
        title = "Music Library Size";
        type = "stat";
        targets = [{
          expr = "node_filesystem_size_bytes{mountpoint=\"/mnt/media\",instance=\"p510.home.freundcloud.com:9100\"} - node_filesystem_avail_bytes{mountpoint=\"/mnt/media\",instance=\"p510.home.freundcloud.com:9100\"}";
          legendFormat = "Used Space";
        }];
        gridPos = { h = 4; w = 6; x = 6; y = 0; };
        fieldConfig = {
          defaults = {
            unit = "bytes";
          };
        };
      }
      {
        id = 3;
        title = "System Load";
        type = "timeseries";
        targets = [
          {
            expr = "node_load1{instance=\"p510.home.freundcloud.com:9100\"}";
            legendFormat = "1m";
          }
          {
            expr = "node_load5{instance=\"p510.home.freundcloud.com:9100\"}";
            legendFormat = "5m";
          }
          {
            expr = "node_load15{instance=\"p510.home.freundcloud.com:9100\"}";
            legendFormat = "15m";
          }
        ];
        gridPos = { h = 8; w = 24; x = 0; y = 4; };
      }
    ];
    time = {
      from = "now-6h";
      to = "now";
    };
    refresh = "30s";
  });

  prowlarrDashboard = pkgs.writeText "prowlarr-dashboard.json" (builtins.toJSON {
    id = null;
    title = "Prowlarr Indexer Manager";
    tags = ["media" "prowlarr" "p510"];
    timezone = "browser";
    panels = [
      {
        id = 1;
        title = "Prowlarr Service Status";
        type = "stat";
        targets = [{
          expr = "systemd_unit_state{name=\"prowlarr.service\",instance=\"p510.home.freundcloud.com:9102\"}";
          legendFormat = "Service State";
        }];
        gridPos = { h = 4; w = 6; x = 0; y = 0; };
        fieldConfig = {
          defaults = {
            mappings = [
              { options = { "1" = { text = "ACTIVE"; color = "green"; }; }; type = "value"; }
              { options = { "0" = { text = "INACTIVE"; color = "red"; }; }; type = "value"; }
            ];
          };
        };
      }
      {
        id = 2;
        title = "Indexer Management Load";
        type = "stat";
        targets = [{
          expr = "node_load1{instance=\"p510.home.freundcloud.com:9100\"}";
          legendFormat = "System Load";
        }];
        gridPos = { h = 4; w = 6; x = 6; y = 0; };
        fieldConfig = {
          defaults = {
            min = 0;
            max = 8;
          };
        };
      }
      {
        id = 3;
        title = "Network Activity";
        type = "timeseries";
        targets = [
          {
            expr = "rate(node_network_receive_bytes_total{device!=\"lo\",instance=\"p510.home.freundcloud.com:9100\"}[5m])";
            legendFormat = "Download";
          }
          {
            expr = "rate(node_network_transmit_bytes_total{device!=\"lo\",instance=\"p510.home.freundcloud.com:9100\"}[5m])";
            legendFormat = "Upload";
          }
        ];
        gridPos = { h = 8; w = 12; x = 0; y = 4; };
      }
      {
        id = 4;
        title = "Memory Usage";
        type = "timeseries";
        targets = [{
          expr = "(1 - (node_memory_MemAvailable_bytes{instance=\"p510.home.freundcloud.com:9100\"} / node_memory_MemTotal_bytes{instance=\"p510.home.freundcloud.com:9100\"})) * 100";
          legendFormat = "Memory %";
        }];
        gridPos = { h = 8; w = 12; x = 12; y = 4; };
      }
    ];
    time = {
      from = "now-6h";
      to = "now";
    };
    refresh = "30s";
  });

  # Centralized Logs Dashboard
  logsDashboard = pkgs.writeText "logs-dashboard.json" (builtins.toJSON {
    id = null;
    title = "Centralized Logs";
    tags = ["logs" "loki" "system"];
    timezone = "browser";
    panels = [
      {
        id = 1;
        title = "System Logs";
        type = "logs";
        targets = [{
          expr = "{job=\"systemd-journal\"} |= \"\"";
          refId = "A";
        }];
        gridPos = { h = 12; w = 24; x = 0; y = 0; };
        options = {
          showTime = true;
          showLabels = true;
          showCommonLabels = false;
          wrapLogMessage = false;
          prettifyLogMessage = false;
          enableLogDetails = true;
          dedupStrategy = "none";
          sortOrder = "Descending";
        };
        datasource = {
          type = "loki";
          uid = "P8E80F9AEF21F6940";
        };
      }
      {
        id = 2;
        title = "Error Logs";
        type = "logs";
        targets = [{
          expr = "{job=\"systemd-journal\"} |~ \"(?i)error|fail|exception|critical\"";
          refId = "B";
        }];
        gridPos = { h = 12; w = 24; x = 0; y = 12; };
        options = {
          showTime = true;
          showLabels = true;
          showCommonLabels = false;
          wrapLogMessage = false;
          prettifyLogMessage = false;
          enableLogDetails = true;
          dedupStrategy = "none";
          sortOrder = "Descending";
        };
        datasource = {
          type = "loki";
          uid = "P8E80F9AEF21F6940";
        };
      }
      {
        id = 3;
        title = "Application Logs";
        type = "logs";
        targets = [{
          expr = "{job=\"application-logs\"} |= \"\"";
          refId = "C";
        }];
        gridPos = { h = 12; w = 24; x = 0; y = 24; };
        options = {
          showTime = true;
          showLabels = true;
          showCommonLabels = false;
          wrapLogMessage = false;
          prettifyLogMessage = false;
          enableLogDetails = true;
          dedupStrategy = "none";
          sortOrder = "Descending";
        };
        datasource = {
          type = "loki";
          uid = "P8E80F9AEF21F6940";
        };
      }
      {
        id = 4;
        title = "Log Volume by Host";
        type = "timeseries";
        targets = [{
          expr = "sum by (host) (rate({job=\"systemd-journal\"}[5m]))";
          refId = "D";
        }];
        gridPos = { h = 8; w = 12; x = 0; y = 36; };
        datasource = {
          type = "loki";
          uid = "P8E80F9AEF21F6940";
        };
      }
      {
        id = 5;
        title = "Log Levels";
        type = "piechart";
        targets = [{
          expr = "sum by (priority) (count_over_time({job=\"systemd-journal\"}[1h]))";
          refId = "E";
        }];
        gridPos = { h = 8; w = 12; x = 12; y = 36; };
        datasource = {
          type = "loki";
          uid = "P8E80F9AEF21F6940";
        };
      }
    ];
    time = {
      from = "now-1h";
      to = "now";
    };
    refresh = "30s";
  });

in {
  config = mkIf (cfg.enable && (cfg.mode == "server" || cfg.mode == "standalone")) {
    services.grafana = {
      enable = true;
      
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = cfg.network.grafanaPort;
          domain = cfg.serverHost;
          root_url = "http://${cfg.serverHost}:${toString cfg.network.grafanaPort}";
        };
        
        security = {
          admin_user = "admin";
          admin_password = "nixos-admin";
          secret_key = "nixos-monitoring-secret-key-change-in-production";
        };
        
        database = {
          type = "sqlite3";
          path = "/var/lib/grafana/grafana.db";
        };
        
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
        };
        
        users = {
          allow_sign_up = false;
          auto_assign_org_role = "Viewer";
        };
        
        "auth.anonymous" = {
          enabled = false;
        };
      };

      # Data source provisioning
      provision = {
        enable = true;
        
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:${toString cfg.network.prometheusPort}";
              isDefault = true;
              jsonData = {
                timeInterval = cfg.scrapeInterval;
                queryTimeout = "60s";
                httpMethod = "POST";
              };
            }
          ] ++ optionals cfg.features.logging [
            {
              name = "Loki";
              type = "loki";
              uid = "P8E80F9AEF21F6940";
              access = "proxy";
              url = "http://localhost:${toString cfg.network.lokiPort}";
              isDefault = false;
              jsonData = {
                maxLines = 1000;
                timeout = "60s";
              };
            }
          ];
        };

        # Dashboard provisioning
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "nixos-dashboards";
              type = "file";
              updateIntervalSeconds = 10;
              allowUiUpdates = true;
              options = {
                path = "/var/lib/grafana/dashboards";
                foldersFromFilesStructure = true;
              };
            }
          ];
        };
      };
    };

    # Create dashboard files and directories
    systemd.tmpfiles.rules = [
      # Ensure Grafana directories are owned by grafana user
      "d /var/lib/grafana 0755 grafana grafana -"
      "d /var/lib/grafana/dashboards 0755 grafana grafana -"
      "d /var/lib/grafana/dashboards/nixos 0755 grafana grafana -"
      "d /var/lib/grafana/dashboards/hosts 0755 grafana grafana -"
      "d /var/lib/grafana/dashboards/media 0755 grafana grafana -"
      "d /var/lib/grafana/dashboards/logs 0755 grafana grafana -"
      
      # System and host dashboards
      "L+ /var/lib/grafana/dashboards/nixos/system-overview.json - - - - ${nixosDashboard}"
      "L+ /var/lib/grafana/dashboards/hosts/p620.json - - - - ${hostDashboard "p620" "AMD"}"
      "L+ /var/lib/grafana/dashboards/hosts/razer.json - - - - ${hostDashboard "razer" "NVIDIA"}"
      "L+ /var/lib/grafana/dashboards/hosts/p510.json - - - - ${hostDashboard "p510" "NVIDIA"}"
      "L+ /var/lib/grafana/dashboards/hosts/dex5550.json - - - - ${hostDashboard "dex5550" "Intel"}"
      
      # Media service dashboards
      "L+ /var/lib/grafana/dashboards/media/plex.json - - - - ${plexDashboard}"
      "L+ /var/lib/grafana/dashboards/media/sonarr.json - - - - ${sonarrDashboard}"
      "L+ /var/lib/grafana/dashboards/media/radarr.json - - - - ${radarrDashboard}"
      "L+ /var/lib/grafana/dashboards/media/lidarr.json - - - - ${lidarrDashboard}"
      "L+ /var/lib/grafana/dashboards/media/prowlarr.json - - - - ${prowlarrDashboard}"
      
      # Logs dashboard
    ] ++ optionals cfg.features.logging [
      "L+ /var/lib/grafana/dashboards/logs/centralized-logs.json - - - - ${logsDashboard}"
    ];

    # Grafana service dependencies
    systemd.services.grafana = {
      after = [ "network.target" "prometheus.service" ] ++ optionals cfg.features.logging [ "loki.service" ];
    };


    # Grafana CLI tools
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "grafana-status" ''
        echo "Grafana Status"
        echo "============="
        echo "URL: http://${cfg.serverHost}:${toString cfg.network.grafanaPort}"
        echo "Admin user: admin"
        echo ""
        echo "Service status:"
        systemctl status grafana --no-pager -l
        echo ""
        echo "Dashboard count:"
        ${curl}/bin/curl -s -u admin:nixos-admin "http://localhost:${toString cfg.network.grafanaPort}/api/search" | ${jq}/bin/jq 'length'
      '')

      (writeShellScriptBin "grafana-dashboards" ''
        echo "Available Grafana Dashboards"
        echo "============================"
        echo ""
        echo "System Dashboards:"
        ${curl}/bin/curl -s -u admin:nixos-admin "http://localhost:${toString cfg.network.grafanaPort}/api/search?tag=nixos" | \
          ${jq}/bin/jq -r '.[] | "  - \(.title) (ID: \(.id))"'
        echo ""
        echo "Host Dashboards:"
        ${curl}/bin/curl -s -u admin:nixos-admin "http://localhost:${toString cfg.network.grafanaPort}/api/search?tag=host" | \
          ${jq}/bin/jq -r '.[] | "  - \(.title) (ID: \(.id))"'
        echo ""
        echo "Media Service Dashboards:"
        ${curl}/bin/curl -s -u admin:nixos-admin "http://localhost:${toString cfg.network.grafanaPort}/api/search?tag=media" | \
          ${jq}/bin/jq -r '.[] | "  - \(.title) (ID: \(.id))"'
      '')

      (writeShellScriptBin "grafana-media-status" ''
        echo "Media Services Dashboard Status"
        echo "==============================="
        echo ""
        echo "Checking media service dashboards..."
        for service in plex sonarr radarr lidarr prowlarr; do
          echo -n "  $service: "
          if ${curl}/bin/curl -s -u admin:nixos-admin "http://localhost:${toString cfg.network.grafanaPort}/api/search?query=$service" | ${jq}/bin/jq -e '.[] | select(.title | test("'$service'"; "i"))' > /dev/null; then
            echo "✓ Available"
          else
            echo "✗ Missing"
          fi
        done
      '')
    ];
  };
}