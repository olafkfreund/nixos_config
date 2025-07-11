# Network Discovery and Device Classification Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.monitoring.networkDiscovery;
in {
  options.monitoring.networkDiscovery = {
    enable = mkEnableOption "Enable network discovery and device classification";
    
    interface = mkOption {
      type = types.str;
      default = "eno1";
      description = "Network interface for monitoring";
    };
    
    networkRange = mkOption {
      type = types.str;
      default = "192.168.1.0/24";
      description = "Network range to scan for devices";
    };
    
    scanInterval = mkOption {
      type = types.str;
      default = "5m";
      description = "Device discovery scan interval";
    };
    
    port = mkOption {
      type = types.int;
      default = 9200;
      description = "Network discovery metrics port";
    };
    
    enableDeepScan = mkOption {
      type = types.bool;
      default = true;
      description = "Enable detailed device fingerprinting";
    };
    
    enableVendorLookup = mkOption {
      type = types.bool;
      default = true;
      description = "Enable MAC vendor identification";
    };
  };

  config = mkIf cfg.enable {
    # Network Discovery Service
    systemd.services.network-discovery = {
      description = "Network Discovery and Device Classification Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "network-discovery";
        Group = "network-discovery";
        Restart = "always";
        RestartSec = "10s";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/network-discovery" "/tmp" ];
        
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [ 
            coreutils curl jq bc nmap iproute2 net-tools 
            arp-scan ethtool python3 gnugrep gnused
          ])}"
        ];
        
        ExecStart = pkgs.writeShellScript "network-discovery" ''
          #!/bin/bash
          set -euo pipefail
          
          # Configuration
          INTERFACE="${cfg.interface}"
          NETWORK_RANGE="${cfg.networkRange}"
          SCAN_INTERVAL="${cfg.scanInterval}"
          EXPORTER_PORT="${toString cfg.port}"
          ENABLE_DEEP_SCAN="${if cfg.enableDeepScan then "true" else "false"}"
          ENABLE_VENDOR_LOOKUP="${if cfg.enableVendorLookup then "true" else "false"}"
          
          # Data directories
          DATA_DIR="/var/lib/network-discovery"
          METRICS_FILE="/tmp/network-discovery-metrics.prom"
          DEVICES_DB="$DATA_DIR/devices.json"
          VENDOR_DB="$DATA_DIR/vendors.json"
          
          # Logging
          log() {
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
          }
          
          # Initialize vendor database
          init_vendor_db() {
              if [[ "$ENABLE_VENDOR_LOOKUP" == "true" && ! -f "$VENDOR_DB" ]]; then
                  log "Downloading MAC vendor database..."
                  curl -s "https://maclookup.app/downloads/json-database/get-db" > "$VENDOR_DB.tmp" 2>/dev/null || {
                      log "Failed to download vendor DB, creating empty one"
                      echo "[]" > "$VENDOR_DB.tmp"
                  }
                  mv "$VENDOR_DB.tmp" "$VENDOR_DB"
              fi
          }
          
          # Get vendor from MAC address
          get_vendor() {
              local mac="$1"
              if [[ "$ENABLE_VENDOR_LOOKUP" == "true" && -f "$VENDOR_DB" ]]; then
                  echo "$mac" | cut -d: -f1-3 | tr '[:lower:]' '[:upper:]' | {
                      read oui
                      jq -r --arg oui "$oui" '.[] | select(.macPrefix == $oui) | .vendorName' "$VENDOR_DB" 2>/dev/null | head -1 || echo "Unknown"
                  }
              else
                  echo "Unknown"
              fi
          }
          
          # Network scanning function
          scan_network() {
              log "Scanning network $NETWORK_RANGE..."
              
              # Get current ARP table
              local arp_entries=$(arp -a | grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}" || true)
              
              # Perform network scan
              local nmap_results=""
              if command -v nmap >/dev/null 2>&1; then
                  nmap_results=$(nmap -sn "$NETWORK_RANGE" 2>/dev/null | grep -E "(Nmap scan report|MAC Address)" || true)
              fi
              
              # Combine results and extract device information
              local devices_json="[]"
              
              # Process ARP entries
              while IFS= read -r line; do
                  if [[ -n "$line" ]]; then
                      local hostname=$(echo "$line" | grep -oE '\([^)]+\)' | tr -d '()' || echo "unknown")
                      local ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "")
                      local mac=$(echo "$line" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' || echo "")
                      
                      if [[ -n "$ip" && -n "$mac" ]]; then
                          local vendor=$(get_vendor "$mac")
                          local timestamp=$(date +%s)
                          
                          # Device type classification
                          local device_type="unknown"
                          case "$hostname" in
                              *p620*|*p510*|*dex5550*|*razer*) device_type="nixos-host" ;;
                              *android*|*iphone*|*samsung*) device_type="mobile" ;;
                              *router*|*gateway*) device_type="network" ;;
                              *tv*|*roku*|*chromecast*) device_type="media" ;;
                              *) 
                                  case "$vendor" in
                                      *Apple*) device_type="apple-device" ;;
                                      *Samsung*) device_type="samsung-device" ;;
                                      *Google*) device_type="google-device" ;;
                                      *) device_type="unknown" ;;
                                  esac
                              ;;
                          esac
                          
                          # Add device to JSON
                          devices_json=$(echo "$devices_json" | jq --arg ip "$ip" --arg mac "$mac" --arg hostname "$hostname" --arg vendor "$vendor" --arg type "$device_type" --arg ts "$timestamp" '. + [{
                              "ip": $ip,
                              "mac": $mac,
                              "hostname": $hostname,
                              "vendor": $vendor,
                              "device_type": $type,
                              "last_seen": ($ts | tonumber),
                              "active": true
                          }]')
                      fi
                  fi
              done <<< "$arp_entries"
              
              # Save devices database
              echo "$devices_json" > "$DEVICES_DB"
              
              log "Discovered $(echo "$devices_json" | jq 'length') devices"
          }
          
          # Deep scan for additional device information
          deep_scan_device() {
              local ip="$1"
              local device_info="{}"
              
              if [[ "$ENABLE_DEEP_SCAN" == "true" ]]; then
                  log "Deep scanning device $ip..."
                  
                  # Port scan for service detection
                  local open_ports=""
                  if command -v nmap >/dev/null 2>&1; then
                      open_ports=$(nmap -F "$ip" 2>/dev/null | grep "open" | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//' || echo "")
                  fi
                  
                  # HTTP banner grabbing
                  local http_banner=""
                  if curl -s --connect-timeout 2 --max-time 5 "http://$ip" >/dev/null 2>&1; then
                      http_banner=$(curl -s --connect-timeout 2 --max-time 5 -I "http://$ip" | head -1 | tr -d '\r\n' || echo "")
                  fi
                  
                  # SSH banner
                  local ssh_banner=""
                  if nc -z -w2 "$ip" 22 2>/dev/null; then
                      ssh_banner=$(timeout 3 nc "$ip" 22 2>/dev/null | head -1 | tr -d '\r\n' || echo "")
                  fi
                  
                  device_info=$(jq -n --arg ports "$open_ports" --arg http "$http_banner" --arg ssh "$ssh_banner" '{
                      "open_ports": $ports,
                      "http_banner": $http,
                      "ssh_banner": $ssh
                  }')
              fi
              
              echo "$device_info"
          }
          
          # Generate Prometheus metrics
          generate_metrics() {
              log "Generating network discovery metrics..."
              
              if [[ ! -f "$DEVICES_DB" ]]; then
                  echo "# No devices database found" > "$METRICS_FILE"
                  return
              fi
              
              local devices=$(cat "$DEVICES_DB")
              local total_devices=$(echo "$devices" | jq 'length')
              local active_devices=$(echo "$devices" | jq '[.[] | select(.active == true)] | length')
              
              cat > "$METRICS_FILE" << EOF
# HELP network_devices_total Total number of discovered devices
# TYPE network_devices_total gauge
network_devices_total $total_devices

# HELP network_devices_active Number of currently active devices
# TYPE network_devices_active gauge
network_devices_active $active_devices

# HELP network_device_info Device information
# TYPE network_device_info gauge
EOF
              
              # Per-device metrics
              echo "$devices" | jq -r '.[] | 
                  "network_device_info{ip=\"" + .ip + "\",mac=\"" + .mac + "\",hostname=\"" + .hostname + "\",vendor=\"" + .vendor + "\",type=\"" + .device_type + "\"} 1"' >> "$METRICS_FILE"
              
              # Device type counts
              echo "" >> "$METRICS_FILE"
              echo "# HELP network_devices_by_type Number of devices by type" >> "$METRICS_FILE"
              echo "# TYPE network_devices_by_type gauge" >> "$METRICS_FILE"
              
              echo "$devices" | jq -r 'group_by(.device_type) | .[] | 
                  "network_devices_by_type{type=\"" + .[0].device_type + "\"} " + (length | tostring)' >> "$METRICS_FILE"
              
              # Vendor distribution
              echo "" >> "$METRICS_FILE"
              echo "# HELP network_devices_by_vendor Number of devices by vendor" >> "$METRICS_FILE"
              echo "# TYPE network_devices_by_vendor gauge" >> "$METRICS_FILE"
              
              echo "$devices" | jq -r 'group_by(.vendor) | .[] | 
                  "network_devices_by_vendor{vendor=\"" + .[0].vendor + "\"} " + (length | tostring)' >> "$METRICS_FILE"
              
              echo "" >> "$METRICS_FILE"
              echo "# HELP network_discovery_last_scan_timestamp Last scan timestamp" >> "$METRICS_FILE"
              echo "# TYPE network_discovery_last_scan_timestamp gauge" >> "$METRICS_FILE"
              echo "network_discovery_last_scan_timestamp $(date +%s)" >> "$METRICS_FILE"
              
              log "Generated metrics for $total_devices devices ($active_devices active)"
          }
          
          # HTTP server for metrics
          serve_metrics() {
              log "Starting network discovery metrics server on port $EXPORTER_PORT..."
              
              python3 -c "
import http.server
import socketserver
import os
import threading
import time

class NetworkDiscoveryHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.end_headers()
            try:
                with open('$METRICS_FILE', 'r') as f:
                    content = f.read()
                    self.wfile.write(content.encode('utf-8'))
            except Exception as e:
                self.wfile.write(f'# Error reading metrics: {str(e)}\n'.encode('utf-8'))
        elif self.path == '/devices':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            try:
                with open('$DEVICES_DB', 'r') as f:
                    content = f.read()
                    self.wfile.write(content.encode('utf-8'))
            except:
                self.wfile.write(b'[]')
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress HTTP logs

print('Starting network discovery HTTP server on port $EXPORTER_PORT')
with socketserver.TCPServer(('0.0.0.0', $EXPORTER_PORT), NetworkDiscoveryHandler) as httpd:
    httpd.serve_forever()
" &
              HTTP_PID=$!
              
              # Main discovery loop
              while true; do
                  scan_network
                  generate_metrics
                  
                  # Convert interval to seconds
                  sleep_seconds=$(echo "${cfg.scanInterval}" | sed 's/s$//' | sed 's/m$/*60/' | bc 2>/dev/null || echo "300")
                  sleep "$sleep_seconds"
              done
          }
          
          # Initialize
          mkdir -p "$DATA_DIR"
          init_vendor_db
          echo "[]" > "$DEVICES_DB"
          echo "# Network discovery starting..." > "$METRICS_FILE"
          
          # Start metrics server and discovery
          serve_metrics
        '';
      };
    };
    
    # Create user and group
    users.users.network-discovery = {
      isSystemUser = true;
      group = "network-discovery";
      description = "Network Discovery service user";
    };
    
    users.groups.network-discovery = {};
    
    # Create data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/network-discovery 0755 network-discovery network-discovery -"
    ];
    
    # Required packages
    environment.systemPackages = with pkgs; [
      nmap
      arp-scan
      ethtool
      iproute2
      net-tools
      curl
      jq
      bc
      python3
      netcat-gnu
    ];
    
    # Open firewall port
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}