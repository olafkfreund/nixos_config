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
        default = 3000;
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
        ];
      })
      
      (mkIf cfg.features.nodeExporter {
        allowedTCPPorts = [ cfg.network.nodeExporterPort ];
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