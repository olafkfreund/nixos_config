{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.monitoring;
  
  # Custom NixOS metrics exporter
  nixosExporter = pkgs.writeShellScriptBin "nixos-exporter" ''
    #!/bin/bash
    
    # NixOS-specific metrics exporter
    # Exports metrics about NixOS system state, generations, etc.
    
    set -euo pipefail
    
    PORT=''${1:-9101}
    
    # Function to output Prometheus metrics
    output_metric() {
        local name="$1"
        local value="$2"
        local help="$3"
        local type="''${4:-gauge}"
        
        echo "# HELP $name $help"
        echo "# TYPE $name $type"
        echo "$name $value"
    }
    
    # Generate metrics
    generate_metrics() {
        echo "# NixOS System Metrics"
        echo "# Generated at $(date -Iseconds)"
        
        # Nix store size (use cached value or skip if taking too long)
        if [[ -d /nix/store ]]; then
            # Use timeout to avoid hanging the exporter
            local store_size=$(timeout 5 du -s /nix/store 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $1 * 1024}' || echo 0)
            output_metric "nixos_store_size_bytes" "$store_size" "Size of /nix/store in bytes (0 if calculation timed out)"
        fi
        
        # Number of generations
        local generations=$(nix-env --list-generations 2>/dev/null | wc -l || echo 0)
        output_metric "nixos_generations_total" "$generations" "Total number of NixOS generations"
        
        # Current generation number
        local current_gen=$(nix-env --list-generations 2>/dev/null | tail -1 | ${pkgs.gawk}/bin/awk '{print $1}' || echo 0)
        output_metric "nixos_generation_current" "$current_gen" "Current NixOS generation number"
        
        # System derivation count in store (with timeout to avoid hanging)
        local derivations=$(timeout 5 find /nix/store -name "*.drv" 2>/dev/null | wc -l || echo 0)
        output_metric "nixos_store_derivations_total" "$derivations" "Number of derivations in Nix store (0 if calculation timed out)"
        
        # Nix daemon status
        local nix_daemon_status=0
        if systemctl is-active nix-daemon >/dev/null 2>&1; then
            nix_daemon_status=1
        fi
        output_metric "nixos_nix_daemon_active" "$nix_daemon_status" "Whether nix-daemon is active (1=active, 0=inactive)"
        
        # Last rebuild time (if available)
        if [[ -f /run/current-system/creation-time ]]; then
            local creation_time=$(cat /run/current-system/creation-time)
            output_metric "nixos_last_rebuild_timestamp" "$creation_time" "Timestamp of last system rebuild"
        fi
        
        # Garbage collection stats (with timeout to avoid hanging)
        local gc_roots=$(timeout 5 nix-store --gc --print-roots 2>/dev/null | wc -l || echo 0)
        output_metric "nixos_gc_roots_total" "$gc_roots" "Number of garbage collection roots (0 if calculation timed out)"
        
        # Channel information
        local channel_count=$(nix-channel --list 2>/dev/null | wc -l || echo 0)
        output_metric "nixos_channels_total" "$channel_count" "Number of Nix channels"
        
        # Boot loader entries (systemd-boot)
        if [[ -d /boot/loader/entries ]]; then
            local boot_entries=$(ls /boot/loader/entries/*.conf 2>/dev/null | wc -l || echo 0)
            output_metric "nixos_boot_entries_total" "$boot_entries" "Number of systemd-boot entries"
        fi
    }
    
    # Simple HTTP server using Python
    serve_metrics() {
        export -f generate_metrics output_metric
        ${pkgs.python3}/bin/python3 -c "
import http.server
import socketserver
import subprocess
import os

class MetricsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            try:
                result = subprocess.run(['${pkgs.bash}/bin/bash', '-c', 'generate_metrics'], 
                                      capture_output=True, text=True, 
                                      env=dict(os.environ))
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; charset=utf-8')
                self.end_headers()
                self.wfile.write(result.stdout.encode())
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'text/plain')
                self.end_headers()
                self.wfile.write(f'Error: {str(e)}'.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(('0.0.0.0', $PORT), MetricsHandler) as httpd:
    httpd.serve_forever()
"
    }
    
    echo "Starting NixOS metrics exporter on port $PORT"
    serve_metrics
  '';

  # Custom systemd service metrics exporter
  systemdExporter = pkgs.writeShellScriptBin "systemd-exporter" ''
    #!/bin/bash
    
    # Systemd service metrics exporter
    # Exports metrics about systemd services, units, etc.
    
    set -euo pipefail
    
    PORT=''${1:-9102}
    
    # Function to output Prometheus metrics
    output_metric() {
        local name="$1"
        local value="$2"
        local help="$3"
        local type="''${4:-gauge}"
        
        echo "# HELP $name $help"
        echo "# TYPE $name $type"
        echo "$name $value"
    }
    
    # Generate systemd metrics
    generate_metrics() {
        echo "# Systemd Service Metrics"
        echo "# Generated at $(date -Iseconds)"
        
        # Total units
        local total_units=$(systemctl list-units --all --no-pager --no-legend | wc -l)
        output_metric "systemd_units_total" "$total_units" "Total number of systemd units"
        
        # Active units
        local active_units=$(systemctl list-units --state=active --no-pager --no-legend | wc -l)
        output_metric "systemd_units_active" "$active_units" "Number of active systemd units"
        
        # Failed units
        local failed_units=$(systemctl list-units --state=failed --no-pager --no-legend | wc -l)
        output_metric "systemd_units_failed" "$failed_units" "Number of failed systemd units"
        
        # Service states
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local unit=$(echo "$line" | ${pkgs.gawk}/bin/awk '{print $1}')
                local state=$(echo "$line" | ${pkgs.gawk}/bin/awk '{print $4}')
                local state_value=0
                
                case "$state" in
                    "active") state_value=1 ;;
                    "failed") state_value=2 ;;
                    "inactive") state_value=0 ;;
                    *) state_value=3 ;;
                esac
                
                echo "systemd_unit_state{unit=\"$unit\",state=\"$state\"} $state_value"
            fi
        done < <(systemctl list-units --type=service --no-pager --no-legend)
        
        # System state
        local system_state=$(systemctl is-system-running 2>/dev/null || echo "unknown")
        local system_state_value=0
        case "$system_state" in
            "running") system_state_value=1 ;;
            "degraded") system_state_value=2 ;;
            "starting") system_state_value=3 ;;
            "stopping") system_state_value=4 ;;
            *) system_state_value=0 ;;
        esac
        output_metric "systemd_system_state" "$system_state_value" "Overall system state (1=running, 2=degraded, 3=starting, 4=stopping, 0=unknown)"
    }
    
    # Simple HTTP server using Python
    serve_metrics() {
        export -f generate_metrics output_metric
        ${pkgs.python3}/bin/python3 -c "
import http.server
import socketserver
import subprocess
import os

class MetricsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            try:
                result = subprocess.run(['${pkgs.bash}/bin/bash', '-c', 'generate_metrics'], 
                                      capture_output=True, text=True,
                                      env=dict(os.environ))
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; charset=utf-8')
                self.end_headers()
                self.wfile.write(result.stdout.encode())
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'text/plain')
                self.end_headers()
                self.wfile.write(f'Error: {str(e)}'.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(('0.0.0.0', $PORT), MetricsHandler) as httpd:
    httpd.serve_forever()
"
    }
    
    echo "Starting systemd metrics exporter on port $PORT"
    serve_metrics
  '';

in {
  config = mkIf (cfg.enable && cfg.features.nodeExporter) {
    # Standard Prometheus node exporter
    services.prometheus.exporters.node = {
      enable = true;
      port = cfg.network.nodeExporterPort;
      listenAddress = "0.0.0.0";
      
      # Enable additional collectors
      enabledCollectors = [
        "systemd"
        "processes"
        "interrupts"
        "ksmd"
        "logind"
        "meminfo_numa"
        "mountstats"
        "network_route"
        "perf"
        "tcpstat"
        "wifi"
        "zfs"
      ];
      
      # Disable collectors that might be problematic
      disabledCollectors = [
        "textfile"  # We'll use custom exporters instead
        "ntp"       # Disable NTP collector to avoid connection refused errors
      ];
    };

    # Custom NixOS metrics exporter service
    systemd.services.nixos-exporter = mkIf cfg.features.nixosMetrics {
      description = "NixOS metrics exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = "monitoring";
        Group = "monitoring";
        ExecStart = "${nixosExporter}/bin/nixos-exporter 9101";
        Restart = "always";
        RestartSec = "10s";
      };
    };

    # Custom systemd metrics exporter service  
    systemd.services.systemd-exporter = mkIf cfg.features.serviceMetrics {
      description = "Systemd metrics exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = "monitoring";
        Group = "monitoring";
        ExecStart = "${systemdExporter}/bin/systemd-exporter 9102";
        Restart = "always";
        RestartSec = "10s";
      };
    };

    # Open firewall ports for custom exporters
    networking.firewall.allowedTCPPorts = mkMerge [
      (mkIf cfg.features.nixosMetrics [ 9101 ])
      (mkIf cfg.features.serviceMetrics [ 9102 ])
    ];

    # Install exporter tools
    environment.systemPackages = [
      nixosExporter
      systemdExporter
      
      (pkgs.writeShellScriptBin "node-exporter-status" ''
        echo "Node Exporter Status"
        echo "==================="
        echo "Standard node exporter: http://localhost:${toString cfg.network.nodeExporterPort}/metrics"
        echo "NixOS exporter: http://localhost:9101/metrics"  
        echo "Systemd exporter: http://localhost:9102/metrics"
        echo ""
        echo "Service status:"
        systemctl status prometheus-node-exporter --no-pager -l || true
        systemctl status nixos-exporter --no-pager -l || true
        systemctl status systemd-exporter --no-pager -l || true
        echo ""
        echo "Metric counts:"
        ${pkgs.curl}/bin/curl -s http://localhost:${toString cfg.network.nodeExporterPort}/metrics | grep -c "^[a-zA-Z]" || echo "Node exporter: Not available"
        ${pkgs.curl}/bin/curl -s http://localhost:9101/metrics | grep -c "^[a-zA-Z]" || echo "NixOS exporter: Not available"
        ${pkgs.curl}/bin/curl -s http://localhost:9102/metrics | grep -c "^[a-zA-Z]" || echo "Systemd exporter: Not available"
      '')
    ];
  };
}