{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.monitoring;
in {
  imports = [
    ./prometheus.nix
    ./grafana.nix
    ./node-exporter.nix
    ./alerting.nix
    ./loki.nix
    ./promtail.nix
    ./gpu-exporter.nix
    ./amd-gpu-exporter.nix
  ];

  options.monitoring = {
    enable = mkEnableOption "Enable monitoring and observability stack";

    mode = mkOption {
      type = types.enum ["server" "client" "standalone"];
      default = "client";
      description = ''
        Monitoring mode:
        - server: Runs Prometheus server, Grafana, and node exporter
        - client: Runs only node exporter (monitored by remote server)
        - standalone: Runs everything locally for single-host monitoring
      '';
    };

    serverHost = mkOption {
      type = types.str;
      default = "p620";
      description = "Hostname of the monitoring server";
    };

    retention = mkOption {
      type = types.str;
      default = "30d";
      description = "Data retention period for metrics";
    };

    logRetention = mkOption {
      type = types.str;
      default = "7d";
      description = "Data retention period for logs";
    };

    scrapeInterval = mkOption {
      type = types.str;
      default = "15s";
      description = "Default scrape interval for metrics collection";
    };

    hosts = mkOption {
      type = types.listOf types.str;
      default = ["p620" "razer" "p510" "dex5550"];
      description = "List of hosts to monitor";
    };

    # Network configuration
    network = {
      prometheusPort = mkOption {
        type = types.int;
        default = 9090;
        description = "Prometheus server port";
      };

      grafanaPort = mkOption {
        type = types.int;
        default = 3001;
        description = "Grafana server port";
      };

      nodeExporterPort = mkOption {
        type = types.int;
        default = 9100;
        description = "Node exporter port";
      };

      alertmanagerPort = mkOption {
        type = types.int;
        default = 9093;
        description = "Alertmanager port";
      };

      lokiPort = mkOption {
        type = types.int;
        default = 3100;
        description = "Loki server port";
      };

      lokiGrpcPort = mkOption {
        type = types.int;
        default = 9095;
        description = "Loki gRPC port";
      };

      promtailPort = mkOption {
        type = types.int;
        default = 9080;
        description = "Promtail server port";
      };

      promtailGrpcPort = mkOption {
        type = types.int;
        default = 9096;
        description = "Promtail gRPC port";
      };

      gpuExporterPort = mkOption {
        type = types.int;
        default = 9400;
        description = "NVIDIA GPU exporter port";
      };

      amdGpuExporterPort = mkOption {
        type = types.int;
        default = 9401;
        description = "AMD GPU exporter port";
      };
    };

    # Feature toggles
    features = {
      nodeExporter = mkOption {
        type = types.bool;
        default = true;
        description = "Enable node exporter for system metrics";
      };

      nixosMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable NixOS-specific metrics collection";
      };

      serviceMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable systemd service metrics";
      };

      aiMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable AI provider usage metrics";
      };

      networkMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network and connectivity metrics";
      };

      alerting = mkOption {
        type = types.bool;
        default = true;
        description = "Enable alerting and notifications";
      };

      logging = mkOption {
        type = types.bool;
        default = true;
        description = "Enable centralized logging with Loki";
      };

      prometheus = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Prometheus metrics server";
      };

      grafana = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Grafana dashboard server";
      };

      gpuMetrics = mkOption {
        type = types.bool;
        default = false;
        description = "Enable NVIDIA GPU metrics collection";
      };

      amdGpuMetrics = mkOption {
        type = types.bool;
        default = false;
        description = "Enable AMD GPU metrics collection";
      };
    };
  };

  config = mkIf cfg.enable {
    # Create monitoring user and group
    users.groups.monitoring = {};
    users.users.monitoring = {
      isSystemUser = true;
      group = "monitoring";
      description = "Monitoring service user";
    };

    # Open firewall ports for monitoring services
    networking.firewall = mkMerge [
      (mkIf (cfg.mode == "server" || cfg.mode == "standalone") {
        allowedTCPPorts = [
          cfg.network.prometheusPort
          cfg.network.grafanaPort
          cfg.network.alertmanagerPort
        ] ++ optionals cfg.features.logging [
          cfg.network.lokiPort
          cfg.network.lokiGrpcPort
        ];
      })
      
      (mkIf cfg.features.nodeExporter {
        allowedTCPPorts = [ cfg.network.nodeExporterPort ];
      })
      
      (mkIf cfg.features.logging {
        allowedTCPPorts = [
          cfg.network.promtailPort
          cfg.network.promtailGrpcPort
        ];
      })
      
      (mkIf cfg.features.gpuMetrics {
        allowedTCPPorts = [ cfg.network.gpuExporterPort ];
      })
      
      (mkIf cfg.features.amdGpuMetrics {
        allowedTCPPorts = [ cfg.network.amdGpuExporterPort ];
      })
    ];

    # Create monitoring data directories
    systemd.tmpfiles.rules = [
      "d /var/lib/monitoring 0755 monitoring monitoring -"
      "d /var/log/monitoring 0755 monitoring monitoring -"
    ];

    # Environment variables for monitoring services
    environment.sessionVariables = {
      MONITORING_MODE = cfg.mode;
      MONITORING_SERVER = cfg.serverHost;
      PROMETHEUS_URL = "http://${cfg.serverHost}:${toString cfg.network.prometheusPort}";
      GRAFANA_URL = "http://${cfg.serverHost}:${toString cfg.network.grafanaPort}";
      LOKI_URL = "http://${cfg.serverHost}:${toString cfg.network.lokiPort}";
    };

    # Install monitoring CLI tools
    environment.systemPackages = with pkgs; [
      prometheus
      grafana
      # Monitoring utilities
      htop
      iotop
      nethogs
      bandwhich
      procs
    ];
  };
}