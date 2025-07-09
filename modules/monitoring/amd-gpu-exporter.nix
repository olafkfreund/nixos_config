{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.monitoring;
  
  # Import our custom AMD SMI exporter package
  # amd-smi-exporter = pkgs.amd-smi-exporter;  # Commented out until package build issues resolved
in {
  config = mkIf (cfg.enable && cfg.features.amdGpuMetrics) {
    # AMD GPU Exporter service using rocm-smi wrapper script
    systemd.services.amd-gpu-exporter = {
      description = "AMD GPU Prometheus Exporter";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "amd-gpu-exporter-wrapper" ''
          export PATH="${lib.makeBinPath [ pkgs.rocmPackages.rocm-smi pkgs.python3 pkgs.coreutils ]}:$PATH"
          exec ${pkgs.python3}/bin/python3 ${pkgs.writeText "amd-gpu-exporter.py" ''
import http.server
import socketserver
import subprocess
import json
import time
import threading
import re
from urllib.parse import urlparse

PORT = ${toString cfg.network.amdGpuExporterPort}
UPDATE_INTERVAL = 15  # seconds

class AMDGPUMetrics:
    def __init__(self):
        self.metrics = {}
        self.lock = threading.Lock()
        self.update_metrics()
        
    def run_rocm_smi(self, args):
        """Run rocm-smi command and return output"""
        try:
            result = subprocess.run(['rocm-smi'] + args, 
                                  capture_output=True, text=True, timeout=10)
            return result.stdout if result.returncode == 0 else None
        except Exception as e:
            print(f"Error running rocm-smi: {e}")
            return None
    
    def parse_temperature(self, output):
        """Parse temperature from rocm-smi output"""
        temps = {}
        if not output:
            return temps
            
        for line in output.split('\n'):
            if 'Temperature (Sensor edge)' in line:
                match = re.search(r':\s*(\d+\.?\d*)', line)
                if match:
                    temps['edge'] = float(match.group(1))
            elif 'Temperature (Sensor junction)' in line:
                match = re.search(r':\s*(\d+\.?\d*)', line)
                if match:
                    temps['junction'] = float(match.group(1))
            elif 'Temperature (Sensor memory)' in line:
                match = re.search(r':\s*(\d+\.?\d*)', line)
                if match:
                    temps['memory'] = float(match.group(1))
        return temps
    
    def parse_power(self, output):
        """Parse power consumption from rocm-smi output"""
        power = {}
        if not output:
            return power
            
        for line in output.split('\n'):
            if 'Average Graphics Package Power' in line:
                match = re.search(r':\s*(\d+\.?\d*)', line)
                if match:
                    power['graphics_package'] = float(match.group(1))
        return power
    
    def parse_utilization(self, output):
        """Parse GPU utilization from rocm-smi output"""
        util = {}
        if not output:
            return util
            
        for line in output.split('\n'):
            if 'GPU use (%)' in line:
                match = re.search(r':\s*(\d+)', line)
                if match:
                    util['gpu'] = float(match.group(1))
        return util
    
    def parse_memory(self, output):
        """Parse memory usage from rocm-smi output"""
        memory = {}
        if not output:
            return memory
            
        for line in output.split('\n'):
            if 'GPU Memory Allocated (VRAM%)' in line:
                match = re.search(r':\s*(\d+)', line)
                if match:
                    memory['vram_used_percent'] = float(match.group(1))
            elif 'GPU Memory Read/Write Activity (%)' in line:
                match = re.search(r':\s*(\d+)', line)
                if match:
                    memory['activity_percent'] = float(match.group(1))
        return memory
    
    def update_metrics(self):
        """Update all metrics from rocm-smi"""
        try:
            # Get temperature data
            temp_output = self.run_rocm_smi(['--showtemp'])
            temperatures = self.parse_temperature(temp_output)
            
            # Get power data
            power_output = self.run_rocm_smi(['--showpower'])
            power = self.parse_power(power_output)
            
            # Get utilization data
            util_output = self.run_rocm_smi(['--showuse'])
            utilization = self.parse_utilization(util_output)
            
            # Get memory data
            memory_output = self.run_rocm_smi(['--showmemuse'])
            memory = self.parse_memory(memory_output)
            
            with self.lock:
                self.metrics = {
                    'temperature': temperatures,
                    'power': power,
                    'utilization': utilization,
                    'memory': memory,
                    'timestamp': time.time()
                }
        except Exception as e:
            print(f"Error updating metrics: {e}")
    
    def get_prometheus_metrics(self):
        """Convert metrics to Prometheus format"""
        with self.lock:
            if not self.metrics:
                return "# No metrics available\n"
            
            output = []
            
            # Temperature metrics
            temps = self.metrics.get('temperature', {})
            if 'edge' in temps:
                output.append(f'amd_gpu_temperature_celsius{{sensor="edge"}} {temps["edge"]}')
            if 'junction' in temps:
                output.append(f'amd_gpu_temperature_celsius{{sensor="junction"}} {temps["junction"]}')
            if 'memory' in temps:
                output.append(f'amd_gpu_temperature_celsius{{sensor="memory"}} {temps["memory"]}')
            
            # Power metrics
            power = self.metrics.get('power', {})
            if 'graphics_package' in power:
                output.append(f'amd_gpu_power_watts{{type="graphics_package"}} {power["graphics_package"]}')
            
            # Utilization metrics
            util = self.metrics.get('utilization', {})
            if 'gpu' in util:
                output.append(f'amd_gpu_utilization_percent {{}} {util["gpu"]}')
            
            # Memory metrics
            memory = self.metrics.get('memory', {})
            if 'vram_used_percent' in memory:
                output.append(f'amd_gpu_memory_used_percent {{}} {memory["vram_used_percent"]}')
            if 'activity_percent' in memory:
                output.append(f'amd_gpu_memory_activity_percent {{}} {memory["activity_percent"]}')
            
            # Add timestamp
            output.append(f'amd_gpu_scrape_timestamp {{}} {self.metrics["timestamp"]}')
            
            return '\n'.join(output) + '\n'

# Global metrics instance
gpu_metrics = AMDGPUMetrics()

def update_metrics_loop():
    """Background thread to update metrics"""
    while True:
        time.sleep(UPDATE_INTERVAL)
        gpu_metrics.update_metrics()

class MetricsHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(gpu_metrics.get_prometheus_metrics().encode())
        elif self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<html><body><h1>AMD GPU Exporter</h1><p><a href="/metrics">Metrics</a></p></body></html>')
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    # Start metrics update thread
    update_thread = threading.Thread(target=update_metrics_loop)
    update_thread.daemon = True
    update_thread.start()
    
    # Start HTTP server
    with socketserver.TCPServer(("", PORT), MetricsHandler) as httpd:
        print(f"AMD GPU Exporter serving on port {PORT}")
        httpd.serve_forever()
          ''}
        ''}";
        Restart = "on-failure";
        RestartSec = "5s";
        User = "amd-gpu-exporter";
        Group = "amd-gpu-exporter";
        
        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = false;  # Need access to GPU devices
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        
        # Memory and CPU limits
        MemoryMax = "128M";
        CPUQuota = "10%";
      };
      
      # Environment for ROCm
      environment = {
        ROCM_PATH = "${pkgs.rocmPackages.rocm-smi}";
      };
    };
    
    # Create user for AMD GPU exporter
    users.groups.amd-gpu-exporter = {};
    users.users.amd-gpu-exporter = {
      isSystemUser = true;
      group = "amd-gpu-exporter";
      description = "AMD GPU Exporter service user";
      extraGroups = [ "video" "render" ];  # Access to GPU devices
    };
    
    # Open firewall port for AMD GPU exporter
    networking.firewall.allowedTCPPorts = [ cfg.network.amdGpuExporterPort ];
    
    # AMD GPU exporter CLI tool
    environment.systemPackages = with pkgs; [
      # amd-smi-exporter  # Commented out until package build issues resolved
      rocmPackages.rocm-smi
      (writeShellScriptBin "amd-gpu-exporter-status" ''
        echo "AMD GPU Exporter Status"
        echo "======================"
        echo "AMD GPU exporter: http://localhost:${toString cfg.network.amdGpuExporterPort}"
        echo "Prometheus target: http://$(hostname):${toString cfg.network.amdGpuExporterPort}/metrics"
        echo ""
        
        echo "Service status:"
        systemctl status amd-gpu-exporter --no-pager -l
        echo ""
        
        echo "AMD GPU exporter metrics:"
        if curl -s http://localhost:${toString cfg.network.amdGpuExporterPort}/metrics > /dev/null 2>&1; then
          echo "AMD GPU exporter: Available"
          curl -s http://localhost:${toString cfg.network.amdGpuExporterPort}/metrics | grep -E "amd_|gpu_|temperature|memory|power|utilization" | head -10
        else
          echo "AMD GPU exporter: Not available"
        fi
        echo ""
        
        echo "AMD GPU status (via rocm-smi):"
        if command -v rocm-smi >/dev/null 2>&1; then
          rocm-smi --showtemp --showpower --showuse --showmemuse --showfan --showclocks || echo "rocm-smi failed - check ROCm installation"
        else
          echo "rocm-smi not available"
        fi
        echo ""
        
        echo "AMD GPU device files:"
        ls -la /dev/kfd /dev/dri/render* 2>/dev/null || echo "No AMD GPU devices found"
        echo ""
        
        echo "ROCm runtime status:"
        if command -v rocminfo >/dev/null 2>&1; then
          rocminfo | grep -E "Name:|Market Name:|Vendor Name:" | head -5
        else
          echo "rocminfo not available"
        fi
      '')
    ];
    
    # Prometheus scrape configuration for AMD GPU metrics
    services.prometheus = mkIf (cfg.mode == "server" || cfg.mode == "standalone") {
      scrapeConfigs = [
        {
          job_name = "amd-gpu-exporter";
          static_configs = [{
            targets = [
              "p620.home.freundcloud.com:${toString cfg.network.amdGpuExporterPort}"
            ];
            labels = {
              service = "amd-gpu-exporter";
              role = "amd-gpu-metrics";
            };
          }];
          scrape_interval = cfg.scrapeInterval;
          metrics_path = "/metrics";
        }
      ];
    };
    
    # Ensure ROCm is available for AMD GPU systems
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.rocm-runtime
      ];
    };
    
    # AMD GPU udev rules for proper device access
    services.udev.extraRules = ''
      # AMD GPU devices
      SUBSYSTEM=="drm", KERNEL=="card*", GROUP="video", MODE="0664"
      SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0664"
      SUBSYSTEM=="drm", KERNEL=="controlD*", GROUP="video", MODE="0664"
      
      # AMD KFD (Kernel Fusion Driver)
      SUBSYSTEM=="kfd", KERNEL=="kfd", GROUP="render", MODE="0664"
    '';
  };
}