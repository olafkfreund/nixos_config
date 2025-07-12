{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.monitoring;
in {
  config = mkIf (cfg.enable && (cfg.mode == "server" || cfg.mode == "standalone")) {
    services.prometheus = {
      enable = true;
      port = cfg.network.prometheusPort;
      listenAddress = "0.0.0.0";
      retentionTime = cfg.retention;
      
      # Global configuration
      globalConfig = {
        scrape_interval = cfg.scrapeInterval;
        evaluation_interval = "15s";
        external_labels = {
          cluster = "nixos-homelab";
          replica = config.networking.hostName;
        };
      };

      # Rules for alerting and recording
      ruleFiles = [
        (pkgs.writeText "nixos-rules.yml" ''
          groups:
            - name: nixos
              rules:
                # System load alerts
                - alert: HighCPUUsage
                  expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High CPU usage on {{ $labels.instance }}"
                    description: "CPU usage is above 80% for more than 5 minutes"

                - alert: HighMemoryUsage
                  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High memory usage on {{ $labels.instance }}"
                    description: "Memory usage is above 90% for more than 5 minutes"

                - alert: LowDiskSpace
                  expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 85
                  for: 10m
                  labels:
                    severity: warning
                  annotations:
                    summary: "Low disk space on {{ $labels.instance }}"
                    description: "Disk usage is above 85% on {{ $labels.mountpoint }}"

                # NixOS specific alerts
                - alert: NixStoreSize
                  expr: node_filesystem_size_bytes{mountpoint="/nix/store"} / 1024 / 1024 / 1024 > 50
                  for: 1h
                  labels:
                    severity: info
                  annotations:
                    summary: "Large Nix store on {{ $labels.instance }}"
                    description: "Nix store size is above 50GB, consider cleanup"

                - alert: SystemdServiceFailed
                  expr: node_systemd_unit_state{state="failed"} == 1
                  for: 0m
                  labels:
                    severity: warning
                  annotations:
                    summary: "Systemd service failed on {{ $labels.instance }}"
                    description: "Service {{ $labels.name }} is in failed state"

            - name: network
              rules:
                - alert: HostDown
                  expr: up == 0
                  for: 1m
                  labels:
                    severity: critical
                  annotations:
                    summary: "Host {{ $labels.instance }} is down"
                    description: "{{ $labels.instance }} has been down for more than 1 minute"

                - alert: HighNetworkTraffic
                  expr: rate(node_network_receive_bytes_total[5m]) > 100 * 1024 * 1024
                  for: 10m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High network traffic on {{ $labels.instance }}"
                    description: "Network receive rate is above 100MB/s"
        '')
      ];

      # Scrape configurations
      scrapeConfigs = [
        # Prometheus itself
        {
          job_name = "prometheus";
          static_configs = [{
            targets = [ "localhost:${toString cfg.network.prometheusPort}" ];
            labels = {
              service = "prometheus";
              role = "server";
            };
          }];
          scrape_interval = "30s";
        }

        # Node exporters on all hosts
        {
          job_name = "node-exporter";
          static_configs = [{
            targets = map (host: "${host}.home.freundcloud.com:${toString cfg.network.nodeExporterPort}") cfg.hosts;
            labels = {
              service = "node-exporter";
              role = "system";
            };
          }];
          scrape_interval = cfg.scrapeInterval;
          metrics_path = "/metrics";
        }

        # NixOS specific metrics
        {
          job_name = "nixos-exporter";
          static_configs = [{
            targets = map (host: "${host}.home.freundcloud.com:9101") cfg.hosts; # Custom NixOS exporter port
            labels = {
              service = "nixos-exporter";
              role = "nixos";
            };
          }];
          scrape_interval = "60s"; # Less frequent for NixOS metrics
        }

        # Systemd services
        {
          job_name = "systemd-exporter";
          static_configs = [{
            targets = map (host: "${host}.home.freundcloud.com:9102") cfg.hosts;
            labels = {
              service = "systemd-exporter";
              role = "services";
            };
          }];
          scrape_interval = "30s";
        }

        # Plex/Tautulli exporter (P510 only)
        {
          job_name = "plex-exporter";
          static_configs = [{
            targets = [ "p510.home.freundcloud.com:9104" ];
            labels = {
              service = "plex";
              role = "media";
            };
          }];
          scrape_interval = "60s";
        }

        # NZBGet exporter (P510 only)
        {
          job_name = "nzbget-exporter";
          static_configs = [{
            targets = [ "p510.home.freundcloud.com:9103" ];
            labels = {
              service = "nzbget";
              role = "media";
            };
          }];
          scrape_interval = "30s";
        }

        # Network discovery exporter (DEX5550 only)
        {
          job_name = "network-discovery";
          static_configs = [{
            targets = [ "dex5550.home.freundcloud.com:9200" ];
            labels = {
              service = "network-discovery";
              role = "network";
            };
          }];
          scrape_interval = "60s";
        }

        # Traffic analyzer exporter (DEX5550 only)
        {
          job_name = "traffic-analyzer";
          static_configs = [{
            targets = [ "dex5550.home.freundcloud.com:9201" ];
            labels = {
              service = "traffic-analyzer";
              role = "network";
            };
          }];
          scrape_interval = "30s";
        }

        # AI metrics exporter (P620 only)
        {
          job_name = "ai-metrics";
          static_configs = [{
            targets = [ "p620.home.freundcloud.com:9105" ];
            labels = {
              service = "ai-metrics";
              role = "ai";
            };
          }];
          scrape_interval = "60s";
        }
      ] ++ 
      # Optional AI metrics scraping
      (optionals cfg.features.aiMetrics [
        {
          job_name = "ollama-exporter";
          static_configs = [{
            targets = map (host: "${host}.home.freundcloud.com:11434") (filter (host: host == "p620" || host == "razer") cfg.hosts);
            labels = {
              service = "ollama";
              role = "ai";
            };
          }];
          scrape_interval = "60s";
          metrics_path = "/metrics";
        }
      ]);

      # Additional configuration flags
      extraFlags = [
        "--web.enable-lifecycle"
        "--web.enable-admin-api"
      ];
    };

    # Prometheus service configuration - use built-in prometheus user
    systemd.services.prometheus = {
      serviceConfig = {
        # Use built-in prometheus user/group from NixOS module
        User = lib.mkForce "prometheus";
        Group = lib.mkForce "prometheus";
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
    };

    # Create custom Prometheus configuration script
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "prometheus-status" ''
        echo "Prometheus Server Status"
        echo "======================"
        echo "URL: http://${cfg.serverHost}:${toString cfg.network.prometheusPort}"
        echo "Data retention: ${cfg.retention}"
        echo "Scrape interval: ${cfg.scrapeInterval}"
        echo ""
        echo "Service status:"
        systemctl status prometheus --no-pager -l
        echo ""
        echo "Targets status:"
        ${curl}/bin/curl -s "http://localhost:${toString cfg.network.prometheusPort}/api/v1/targets" | ${jq}/bin/jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
      '')

      (writeShellScriptBin "prometheus-reload" ''
        echo "Reloading Prometheus configuration..."
        ${curl}/bin/curl -X POST http://localhost:${toString cfg.network.prometheusPort}/-/reload
        echo "Configuration reloaded"
      '')
    ];
  };
}