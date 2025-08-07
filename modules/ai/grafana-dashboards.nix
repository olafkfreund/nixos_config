# AI Analysis Grafana Dashboards
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.grafanaDashboards;
in
{
  options.ai.grafanaDashboards = {
    enable = mkEnableOption "Enable AI analysis Grafana dashboards";
  };

  config = mkIf cfg.enable {
    services.grafana.provision.dashboards.settings.providers = [
      {
        name = "ai-analysis";
        type = "file";
        disableDeletion = true;
        updateIntervalSeconds = 10;
        options.path = "/var/lib/grafana/ai-dashboards";
      }
    ];

    # Create AI Analysis Overview Dashboard
    systemd.tmpfiles.rules = [
      ''d /var/lib/grafana/ai-dashboards 0755 grafana grafana -''
    ];

    # AI Analysis Overview Dashboard
    environment.etc."grafana/dashboards/ai-analysis-overview.json".text = builtins.toJSON {
      annotations = {
        list = [
          {
            builtIn = 1;
            datasource = {
              type = "grafana";
              uid = "-- Grafana --";
            };
            enable = true;
            hide = true;
            iconColor = "rgba(0, 211, 255, 1)";
            name = "Annotations & Alerts";
            type = "dashboard";
          }
        ];
      };
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 0;
      id = null;
      links = [ ];
      liveNow = false;
      panels = [
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "AI Analysis System Status";
          fieldConfig = {
            defaults = {
              color = {
                mode = "thresholds";
              };
              custom = {
                align = "auto";
                cellOptions = {
                  type = "auto";
                };
                inspect = false;
              };
              mappings = [ ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                ];
              };
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 0;
            y = 0;
          };
          id = 1;
          options = {
            showHeader = true;
          };
          pluginVersion = "9.5.2";
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "ai_exporter_up{job=\"ai-metrics\"}";
              format = "table";
              instant = true;
              refId = "A";
            }
          ];
          title = "AI Analysis Services Status";
          type = "table";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "Memory usage across all hosts";
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 0;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  vis = false;
                };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [ ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                  {
                    color = "yellow";
                    value = 75;
                  }
                  {
                    color = "red";
                    value = 90;
                  }
                ];
              };
              unit = "percent";
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 12;
            y = 0;
          };
          id = 2;
          options = {
            legend = {
              calcs = [ ];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              mode = "single";
              sort = "none";
            };
          };
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))";
              refId = "A";
            }
          ];
          title = "Memory Usage by Host";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "Disk usage across all hosts";
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 0;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  vis = false;
                };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [ ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                  {
                    color = "yellow";
                    value = 75;
                  }
                  {
                    color = "red";
                    value = 90;
                  }
                ];
              };
              unit = "percent";
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 24;
            x = 0;
            y = 8;
          };
          id = 3;
          options = {
            legend = {
              calcs = [ ];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              mode = "single";
              sort = "none";
            };
          };
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "100 * (1 - (node_filesystem_avail_bytes{fstype!=\"tmpfs\",fstype!=\"ramfs\",fstype!=\"squashfs\",mountpoint=\"/\"} / node_filesystem_size_bytes{fstype!=\"tmpfs\",fstype!=\"ramfs\",fstype!=\"squashfs\",mountpoint=\"/\"}))";
              refId = "A";
            }
          ];
          title = "Root Filesystem Usage by Host";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "AI Analysis Performance Metrics";
          fieldConfig = {
            defaults = {
              color = {
                mode = "thresholds";
              };
              custom = {
                align = "auto";
                cellOptions = {
                  type = "auto";
                };
                inspect = false;
              };
              mappings = [ ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                ];
              };
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 0;
            y = 16;
          };
          id = 4;
          options = {
            showHeader = true;
          };
          pluginVersion = "9.5.2";
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "ai_analysis_files_recent{job=\"ai-metrics\"}";
              format = "table";
              instant = true;
              refId = "A";
            }
          ];
          title = "AI Analysis Files";
          type = "table";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "Memory optimization actions taken";
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 0;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  vis = false;
                };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [ ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                ];
              };
              unit = "short";
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 12;
            x = 12;
            y = 16;
          };
          id = 5;
          options = {
            legend = {
              calcs = [ ];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              mode = "single";
              sort = "none";
            };
          };
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "ai_memory_optimization_status{job=\"ai-metrics\"}";
              refId = "A";
            }
          ];
          title = "Memory Optimization Actions";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "AI Analysis execution duration";
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 0;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  vis = false;
                };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [ ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                ];
              };
              unit = "s";
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 24;
            x = 0;
            y = 24;
          };
          id = 6;
          options = {
            legend = {
              calcs = [ ];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              mode = "single";
              sort = "none";
            };
          };
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "ai_last_metrics_update{job=\"ai-metrics\"}";
              refId = "A";
            }
          ];
          title = "AI Last Update Timestamp";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "AI System CPU Usage";
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 0;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  vis = false;
                };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [ ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                  {
                    color = "yellow";
                    value = 70;
                  }
                  {
                    color = "red";
                    value = 85;
                  }
                ];
              };
              unit = "percent";
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 8;
            x = 0;
            y = 32;
          };
          id = 7;
          options = {
            legend = {
              calcs = [ ];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              mode = "single";
              sort = "none";
            };
          };
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "ai_system_cpu_usage_percent{job=\"ai-metrics\"}";
              refId = "A";
            }
          ];
          title = "AI System CPU Usage";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "AI System Memory Usage";
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic";
              };
              custom = {
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 0;
                gradientMode = "none";
                hideFrom = {
                  legend = false;
                  tooltip = false;
                  vis = false;
                };
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                scaleDistribution = {
                  type = "linear";
                };
                showPoints = "auto";
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle = {
                  mode = "off";
                };
              };
              mappings = [ ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                  {
                    color = "yellow";
                    value = 75;
                  }
                  {
                    color = "red";
                    value = 90;
                  }
                ];
              };
              unit = "percent";
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 8;
            x = 8;
            y = 32;
          };
          id = 8;
          options = {
            legend = {
              calcs = [ ];
              displayMode = "list";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              mode = "single";
              sort = "none";
            };
          };
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "ai_system_memory_usage_percent{job=\"ai-metrics\"}";
              refId = "A";
            }
          ];
          title = "AI System Memory Usage";
          type = "timeseries";
        }
        {
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
          description = "AI Remediation Status";
          fieldConfig = {
            defaults = {
              color = {
                mode = "thresholds";
              };
              custom = {
                align = "auto";
                cellOptions = {
                  type = "auto";
                };
                inspect = false;
              };
              mappings = [
                {
                  options = {
                    "0" = {
                      text = "Disabled";
                      color = "red";
                    };
                    "1" = {
                      text = "Enabled";
                      color = "green";
                    };
                  };
                  type = "value";
                }
              ];
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                ];
              };
            };
            overrides = [ ];
          };
          gridPos = {
            h = 8;
            w = 8;
            x = 16;
            y = 32;
          };
          id = 9;
          options = {
            showHeader = true;
          };
          pluginVersion = "9.5.2";
          targets = [
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "ai_remediation_safe_mode{job=\"ai-metrics\"}";
              format = "table";
              instant = true;
              refId = "A";
            }
            {
              datasource = {
                type = "prometheus";
                uid = "prometheus";
              };
              expr = "ai_remediation_self_healing{job=\"ai-metrics\"}";
              format = "table";
              instant = true;
              refId = "B";
            }
          ];
          title = "AI Remediation Status";
          type = "table";
        }
      ];
      refresh = "5s";
      schemaVersion = 37;
      style = "dark";
      tags = [ "ai" "analysis" "monitoring" ];
      templating = {
        list = [ ];
      };
      time = {
        from = "now-1h";
        to = "now";
      };
      timepicker = { };
      timezone = "";
      title = "AI Analysis Overview";
      uid = "ai-analysis-overview";
      version = 1;
      weekStart = "";
    };

    # Create symlink to the dashboard
    systemd.services.grafana-ai-dashboards = {
      description = "Setup AI Analysis Grafana Dashboards";
      after = [ "grafana.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "grafana";
        Group = "grafana";
        ExecStart = pkgs.writeShellScript "setup-ai-dashboards" ''
          mkdir -p /var/lib/grafana/ai-dashboards
          ln -sf /etc/grafana/dashboards/ai-analysis-overview.json /var/lib/grafana/ai-dashboards/

          # Restart Grafana to load the new dashboards
          systemctl reload grafana || true
        '';
      };
    };
  };
}
