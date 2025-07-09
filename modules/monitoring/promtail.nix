{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.monitoring;
  hostname = config.networking.hostName;
  
  # Promtail configuration
  promtailConfig = {
    server = {
      http_listen_port = cfg.network.promtailPort;
      grpc_listen_port = cfg.network.promtailGrpcPort;
      log_level = "info";
    };
    
    positions = {
      filename = "/var/lib/promtail/positions.yaml";
    };
    
    clients = [{
      url = "http://${cfg.serverHost}:${toString cfg.network.lokiPort}/loki/api/v1/push";
      tenant_id = "tenant1";
      
      # Backoff configuration for reliability
      backoff_config = {
        min_period = "500ms";
        max_period = "5m";
        max_retries = 10;
      };
    }];
    
    scrape_configs = [
      # System journal logs
      {
        job_name = "journal";
        journal = {
          max_age = "12h";
          labels = {
            job = "systemd-journal";
            host = hostname;
          };
        };
        relabel_configs = [
          {
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }
          {
            source_labels = [ "__journal__hostname" ];
            target_label = "hostname";
          }
          {
            source_labels = [ "__journal_priority" ];
            target_label = "priority";
          }
          {
            source_labels = [ "__journal_syslog_identifier" ];
            target_label = "syslog_identifier";
          }
        ];
      }
      
      # Nginx access logs (if nginx is enabled)
      {
        job_name = "nginx-access";
        static_configs = [{
          targets = ["localhost"];
          labels = {
            job = "nginx-access";
            host = hostname;
            __path__ = "/var/log/nginx/access.log";
          };
        }];
      }
      
      # Nginx error logs (if nginx is enabled)
      {
        job_name = "nginx-error";
        static_configs = [{
          targets = ["localhost"];
          labels = {
            job = "nginx-error";
            host = hostname;
            __path__ = "/var/log/nginx/error.log";
          };
        }];
      }
      
      # Application logs directory
      {
        job_name = "app-logs";
        static_configs = [{
          targets = ["localhost"];
          labels = {
            job = "application-logs";
            host = hostname;
            __path__ = "/var/log/applications/**/*.log";
          };
        }];
      }
      
      # Kernel logs
      {
        job_name = "kernel";
        static_configs = [{
          targets = ["localhost"];
          labels = {
            job = "kernel";
            host = hostname;
            __path__ = "/var/log/kern.log";
          };
        }];
      }
      
      # Docker container logs (if docker is enabled)
      {
        job_name = "docker";
        static_configs = [{
          targets = ["localhost"];
          labels = {
            job = "docker";
            host = hostname;
            __path__ = "/var/lib/docker/containers/*/*.log";
          };
        }];
        pipeline_stages = [
          {
            json = {
              expressions = {
                output = "log";
                stream = "stream";
                attrs = "";
              };
            };
          }
          {
            json = {
              expressions = {
                tag = "attrs.tag";
              };
              source = "attrs";
            };
          }
          {
            regex = {
              expression = "^(?P<container_name>(?:[^/]*/)*)(?P<container_id>[^/]+)$";
              source = "tag";
            };
          }
          {
            timestamp = {
              source = "time";
              format = "RFC3339Nano";
            };
          }
          {
            labels = {
              stream = null;
              container_name = null;
              container_id = null;
            };
          }
          {
            output = {
              source = "output";
            };
          }
        ];
      }
      
      # Custom application logs for specific services
      {
        job_name = "monitoring-logs";
        static_configs = [{
          targets = ["localhost"];
          labels = {
            job = "monitoring";
            host = hostname;
            __path__ = "/var/log/monitoring/*.log";
          };
        }];
      }
    ];
  };
  
  # Promtail configuration file
  promtailConfigFile = pkgs.writeText "promtail.yaml" ''
    server:
      http_listen_port: ${toString cfg.network.promtailPort}
      grpc_listen_port: ${toString cfg.network.promtailGrpcPort}
      log_level: info
      
    positions:
      filename: /var/lib/promtail/positions.yaml
      
    clients:
      - url: http://${cfg.serverHost}:${toString cfg.network.lokiPort}/loki/api/v1/push
        tenant_id: tenant1
        backoff_config:
          min_period: 500ms
          max_period: 5m
          max_retries: 10
          
    scrape_configs:
      - job_name: journal
        journal:
          max_age: 12h
          labels:
            job: systemd-journal
            host: ${hostname}
        relabel_configs:
          - source_labels: [__journal__systemd_unit]
            target_label: unit
          - source_labels: [__journal__hostname]
            target_label: hostname
          - source_labels: [__journal_priority]
            target_label: priority
          - source_labels: [__journal_syslog_identifier]
            target_label: syslog_identifier
            
      - job_name: nginx-access
        static_configs:
          - targets: [localhost]
            labels:
              job: nginx-access
              host: ${hostname}
              __path__: /var/log/nginx/access.log
              
      - job_name: nginx-error
        static_configs:
          - targets: [localhost]
            labels:
              job: nginx-error
              host: ${hostname}
              __path__: /var/log/nginx/error.log
              
      - job_name: app-logs
        static_configs:
          - targets: [localhost]
            labels:
              job: application-logs
              host: ${hostname}
              __path__: /var/log/applications/**/*.log
              
      - job_name: monitoring-logs
        static_configs:
          - targets: [localhost]
            labels:
              job: monitoring
              host: ${hostname}
              __path__: /var/log/monitoring/*.log
  '';
  
in {
  config = mkIf (cfg.enable && cfg.features.logging) {
    # Promtail service
    systemd.services.promtail = {
      description = "Promtail log shipping agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = "promtail";
        Group = "promtail";
        ExecStart = "${pkgs.grafana-loki}/bin/promtail -config.file=${promtailConfigFile}";
        Restart = "always";
        RestartSec = "10s";
        
        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/promtail" "/var/log" ];
        ReadOnlyPaths = [ "/var/lib/docker" "/run/systemd/journal" ];
        
        # Resource limits
        MemoryMax = "128M";
        CPUQuota = "25%";
      };
      
      preStart = ''
        # Create necessary directories
        mkdir -p /var/lib/promtail
        chown promtail:promtail /var/lib/promtail
        chmod 755 /var/lib/promtail
        
        # Create application log directory
        mkdir -p /var/log/applications
        chown promtail:promtail /var/log/applications
        chmod 755 /var/log/applications
      '';
    };
    
    # Create promtail user and group
    users.groups.promtail = {};
    users.users.promtail = {
      isSystemUser = true;
      group = "promtail";
      description = "Promtail service user";
      home = "/var/lib/promtail";
      createHome = false;
      
      # Add to required groups for log access
      extraGroups = [
        "systemd-journal"
        "adm"
      ] ++ optionals config.virtualisation.docker.enable [
        "docker"
      ];
    };
    
    # Create data directories
    systemd.tmpfiles.rules = [
      "d /var/lib/promtail 0755 promtail promtail -"
      "d /var/log/applications 0755 promtail promtail -"
    ];
    
    # Open firewall ports for Promtail (if needed for debugging)
    networking.firewall.allowedTCPPorts = mkIf (cfg.mode == "server") [
      cfg.network.promtailPort
      cfg.network.promtailGrpcPort
    ];
    
    # Install Promtail CLI tools
    environment.systemPackages = with pkgs; [
      grafana-loki  # Includes promtail
      
      # Promtail management script
      (pkgs.writeShellScriptBin "promtail-status" ''
        echo "Promtail Status"
        echo "==============="
        echo "Promtail server: http://localhost:${toString cfg.network.promtailPort}"
        echo "Loki server: http://${cfg.serverHost}:${toString cfg.network.lokiPort}"
        echo "Hostname: ${hostname}"
        echo ""
        echo "Service status:"
        systemctl status promtail --no-pager -l || true
        echo ""
        echo "Promtail metrics:"
        ${pkgs.curl}/bin/curl -s http://localhost:${toString cfg.network.promtailPort}/metrics | grep -E "(promtail_|loki_)" | head -10 || echo "Promtail metrics: Not available"
        echo ""
        echo "Position file:"
        ls -la /var/lib/promtail/positions.yaml 2>/dev/null || echo "No position file yet"
        echo ""
        echo "Recent log shipping status:"
        journalctl -u promtail --since "5 minutes ago" --no-pager -l | tail -10 || echo "No recent logs"
      '')
    ];
  };
}