# AI Analysis Prometheus Alerting Rules
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.ai.prometheusAlerts;
in
{
  options.ai.prometheusAlerts = {
    enable = mkEnableOption "Enable AI analysis Prometheus alerts";
  };

  config = mkIf cfg.enable {
    services.prometheus.ruleFiles = [
      (pkgs.writeText "ai-analysis-alerts.yml" ''
        groups:
          - name: ai-analysis
            rules:
              # AI Analysis Service Health
              - alert: AIAnalysisServiceDown
                expr: up{job="ai-analysis"} == 0
                for: 5m
                labels:
                  severity: critical
                  service: ai-analysis
                annotations:
                  summary: "AI Analysis service is down on {{ $labels.instance }}"
                  description: "AI Analysis service has been down for more than 5 minutes on {{ $labels.instance }}"

              # Memory Optimization Alerts
              - alert: MemoryUsageHigh
                expr: 100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 85
                for: 10m
                labels:
                  severity: warning
                  service: memory-optimization
                annotations:
                  summary: "High memory usage detected on {{ $labels.instance }}"
                  description: "Memory usage is above 85% ({{ $value }}%) on {{ $labels.instance }} for more than 10 minutes"

              - alert: MemoryUsageCritical
                expr: 100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 95
                for: 5m
                labels:
                  severity: critical
                  service: memory-optimization
                annotations:
                  summary: "Critical memory usage on {{ $labels.instance }}"
                  description: "Memory usage is above 95% ({{ $value }}%) on {{ $labels.instance }} for more than 5 minutes"

              # Disk Space Alerts
              - alert: DiskSpaceWarning
                expr: 100 * (1 - (node_filesystem_avail_bytes{fstype!="tmpfs",fstype!="ramfs",fstype!="squashfs",mountpoint="/"} / node_filesystem_size_bytes{fstype!="tmpfs",fstype!="ramfs",fstype!="squashfs",mountpoint="/"})) > 80
                for: 10m
                labels:
                  severity: warning
                  service: disk-optimization
                annotations:
                  summary: "Disk space warning on {{ $labels.instance }}"
                  description: "Root filesystem usage is above 80% ({{ $value }}%) on {{ $labels.instance }}"

              - alert: DiskSpaceCritical
                expr: 100 * (1 - (node_filesystem_avail_bytes{fstype!="tmpfs",fstype!="ramfs",fstype!="squashfs",mountpoint="/"} / node_filesystem_size_bytes{fstype!="tmpfs",fstype!="ramfs",fstype!="squashfs",mountpoint="/"})) > 90
                for: 5m
                labels:
                  severity: critical
                  service: disk-optimization
                annotations:
                  summary: "Critical disk space on {{ $labels.instance }}"
                  description: "Root filesystem usage is above 90% ({{ $value }}%) on {{ $labels.instance }}"

              # P510 Specific Critical Alert (already at 79.6%)
              - alert: P510DiskSpaceUrgent
                expr: 100 * (1 - (node_filesystem_avail_bytes{fstype!="tmpfs",fstype!="ramfs",fstype!="squashfs",mountpoint="/",instance="p510.home.freundcloud.com:9100"} / node_filesystem_size_bytes{fstype!="tmpfs",fstype!="ramfs",fstype!="squashfs",mountpoint="/",instance="p510.home.freundcloud.com:9100"})) > 75
                for: 1m
                labels:
                  severity: critical
                  service: disk-optimization
                  host: p510
                annotations:
                  summary: "P510 disk space urgent - already at dangerous levels"
                  description: "P510 root filesystem usage is {{ $value }}% - needs immediate attention"

              # AI Analysis Performance Alerts
              - alert: AIAnalysisSlowPerformance
                expr: ai_analysis_duration_seconds > 300
                for: 5m
                labels:
                  severity: warning
                  service: ai-analysis
                annotations:
                  summary: "AI Analysis taking too long on {{ $labels.instance }}"
                  description: "AI Analysis duration is {{ $value }}s, which is above the 5-minute threshold"

              - alert: AIAnalysisFailures
                expr: rate(ai_analysis_failures_total[5m]) > 0.1
                for: 5m
                labels:
                  severity: warning
                  service: ai-analysis
                annotations:
                  summary: "AI Analysis failures increasing on {{ $labels.instance }}"
                  description: "AI Analysis failure rate is {{ $value }} per second over the last 5 minutes"

              # Memory Optimization Effectiveness
              - alert: MemoryOptimizationIneffective
                expr: rate(memory_optimization_actions_total[10m]) > 0 and increase(node_memory_MemAvailable_bytes[10m]) < 0
                for: 10m
                labels:
                  severity: warning
                  service: memory-optimization
                annotations:
                  summary: "Memory optimization not effective on {{ $labels.instance }}"
                  description: "Memory optimization actions are running but available memory is not increasing"

              # Configuration Drift Detection
              - alert: ConfigurationDriftDetected
                expr: config_drift_detected > 0
                for: 1m
                labels:
                  severity: warning
                  service: config-drift
                annotations:
                  summary: "Configuration drift detected on {{ $labels.instance }}"
                  description: "Configuration drift has been detected - manual review recommended"

              # Log Analysis Alerts
              - alert: HighErrorLogVolume
                expr: rate(log_errors_total[5m]) > 10
                for: 5m
                labels:
                  severity: warning
                  service: log-analysis
                annotations:
                  summary: "High error log volume on {{ $labels.instance }}"
                  description: "Error log rate is {{ $value }} per second, which is above normal levels"

              # Predictive Maintenance Alerts
              - alert: PredictedSystemFailure
                expr: predicted_failure_probability > 0.8
                for: 1m
                labels:
                  severity: critical
                  service: predictive-maintenance
                annotations:
                  summary: "Predicted system failure on {{ $labels.instance }}"
                  description: "Predictive maintenance model indicates {{ $value }}% probability of failure"

              # ChromaDB Health (for RAG functionality)
              - alert: ChromaDBDown
                expr: up{job="chromadb"} == 0
                for: 5m
                labels:
                  severity: warning
                  service: chromadb
                annotations:
                  summary: "ChromaDB service is down on {{ $labels.instance }}"
                  description: "ChromaDB service has been down for more than 5 minutes - RAG functionality affected"

              # Nix Store Growth Alert
              - alert: NixStoreGrowthRapid
                expr: increase(node_filesystem_size_bytes{mountpoint="/nix/store"}[1h]) > 1073741824
                for: 1h
                labels:
                  severity: warning
                  service: nix-optimization
                annotations:
                  summary: "Rapid Nix store growth on {{ $labels.instance }}"
                  description: "Nix store has grown by {{ $value | humanize1024 }}B in the last hour"

              # System Load Alerts
              - alert: HighSystemLoad
                expr: node_load1 > 8
                for: 10m
                labels:
                  severity: warning
                  service: system-performance
                annotations:
                  summary: "High system load on {{ $labels.instance }}"
                  description: "1-minute load average is {{ $value }}, which is high for this system"

              # AI Provider API Failures
              - alert: AIProviderAPIFailures
                expr: rate(ai_provider_api_failures_total[5m]) > 0.1
                for: 5m
                labels:
                  severity: warning
                  service: ai-providers
                annotations:
                  summary: "AI Provider API failures on {{ $labels.instance }}"
                  description: "AI Provider API failure rate is {{ $value }} per second"
      '')
    ];
  };
}
