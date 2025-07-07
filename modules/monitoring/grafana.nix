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
    dashboard = {
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
    };
  });

  # Host-specific dashboard generator
  hostDashboard = hostname: hardware: pkgs.writeText "${hostname}-dashboard.json" (builtins.toJSON {
    dashboard = {
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
            expr = "up{instance=\"${hostname}:9100\"}";
            legendFormat = "Status";
          }];
          gridPos = { h = 4; w = 6; x = 0; y = 0; };
        }
        {
          id = 2;
          title = "Uptime";
          type = "stat";
          targets = [{
            expr = "node_time_seconds{instance=\"${hostname}:9100\"} - node_boot_time_seconds{instance=\"${hostname}:9100\"}";
            legendFormat = "Uptime";
          }];
          gridPos = { h = 4; w = 6; x = 6; y = 0; };
        }
      ] ++ (if (hardware == "AMD") then [
        {
          id = 10;
          title = "ROCm GPU Usage";
          type = "timeseries";
          targets = [{
            expr = "rocm_gpu_usage{instance=\"${hostname}:9100\"}";
            legendFormat = "GPU {{device}}";
          }];
          gridPos = { h = 8; w = 12; x = 0; y = 4; };
        }
      ] else if (hardware == "NVIDIA") then [
        {
          id = 11;
          title = "NVIDIA GPU Usage";
          type = "timeseries";
          targets = [{
            expr = "nvidia_gpu_utilization{instance=\"${hostname}:9100\"}";
            legendFormat = "GPU {{device}}";
          }];
          gridPos = { h = 8; w = 12; x = 0; y = 4; };
        }
      ] else []);
      time = {
        from = "now-6h";
        to = "now";
      };
      refresh = "30s";
    };
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
          admin_password = "$__file{/run/secrets/grafana-admin-password}";
          secret_key = "$__file{/run/secrets/grafana-secret-key}";
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
      "L+ /var/lib/grafana/dashboards/nixos/system-overview.json - - - - ${nixosDashboard}"
      "L+ /var/lib/grafana/dashboards/hosts/p620.json - - - - ${hostDashboard "p620" "AMD"}"
      "L+ /var/lib/grafana/dashboards/hosts/razer.json - - - - ${hostDashboard "razer" "NVIDIA"}"
      "L+ /var/lib/grafana/dashboards/hosts/p510.json - - - - ${hostDashboard "p510" "NVIDIA"}"
      "L+ /var/lib/grafana/dashboards/hosts/dex5550.json - - - - ${hostDashboard "dex5550" "Intel"}"
    ];

    # Grafana service dependencies
    systemd.services.grafana = {
      after = [ "network.target" "prometheus.service" ];
    };

    # Create monitoring secrets if they don't exist
    systemd.services.grafana-setup = {
      description = "Setup Grafana secrets";
      wantedBy = [ "grafana.service" ];
      before = [ "grafana.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "grafana-setup" ''
          # Create secrets directory if it doesn't exist
          mkdir -p /run/secrets
          
          # Generate admin password if it doesn't exist
          if [[ ! -f /run/secrets/grafana-admin-password ]]; then
            echo "nixos-admin" > /run/secrets/grafana-admin-password
            chmod 600 /run/secrets/grafana-admin-password
          fi
          
          # Generate secret key if it doesn't exist
          if [[ ! -f /run/secrets/grafana-secret-key ]]; then
            ${pkgs.openssl}/bin/openssl rand -hex 32 > /run/secrets/grafana-secret-key
            chmod 600 /run/secrets/grafana-secret-key
          fi
        '';
      };
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
        ${curl}/bin/curl -s -u admin:nixos-admin "http://localhost:${toString cfg.network.grafanaPort}/api/search" | \
          ${jq}/bin/jq -r '.[] | "\(.title) (ID: \(.id)) - \(.url)"'
      '')
    ];
  };
}