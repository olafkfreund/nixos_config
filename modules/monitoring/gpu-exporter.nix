{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.monitoring;
in {
  config = mkIf (cfg.enable && cfg.features.gpuMetrics) {
    # NVIDIA GPU Exporter service
    systemd.services.nvidia-gpu-exporter = {
      description = "NVIDIA GPU Prometheus Exporter";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.prometheus-nvidia-gpu-exporter}/bin/nvidia_gpu_prometheus_exporter --web.listen-address=:${toString cfg.network.gpuExporterPort}";
        Restart = "on-failure";
        RestartSec = "5s";
        User = "nvidia-gpu-exporter";
        Group = "nvidia-gpu-exporter";
        
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
        MemoryMax = "64M";
        CPUQuota = "10%";
      };
      
      # Environment for NVIDIA drivers
      environment = {
        NVIDIA_VISIBLE_DEVICES = "all";
        NVIDIA_DRIVER_CAPABILITIES = "compute,utility";
      };
    };
    
    # Create user for GPU exporter
    users.groups.nvidia-gpu-exporter = {};
    users.users.nvidia-gpu-exporter = {
      isSystemUser = true;
      group = "nvidia-gpu-exporter";
      description = "NVIDIA GPU Exporter service user";
      extraGroups = [ "video" ];  # Access to GPU devices
    };
    
    # Open firewall port for GPU exporter
    networking.firewall.allowedTCPPorts = [ cfg.network.gpuExporterPort ];
    
    # GPU exporter CLI tool
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "gpu-exporter-status" ''
        echo "GPU Exporter Status"
        echo "=================="
        echo "GPU exporter: http://localhost:${toString cfg.network.gpuExporterPort}"
        echo "Prometheus target: http://$(hostname):${toString cfg.network.gpuExporterPort}/metrics"
        echo ""
        
        echo "Service status:"
        systemctl status nvidia-gpu-exporter --no-pager -l
        echo ""
        
        echo "GPU exporter metrics:"
        if curl -s http://localhost:${toString cfg.network.gpuExporterPort}/metrics > /dev/null 2>&1; then
          echo "GPU exporter: Available"
          curl -s http://localhost:${toString cfg.network.gpuExporterPort}/metrics | grep -E "nvidia_gpu_|temperature|memory|utilization" | head -10
        else
          echo "GPU exporter: Not available"
        fi
        echo ""
        
        echo "NVIDIA GPU status:"
        if command -v nvidia-smi >/dev/null 2>&1; then
          nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free,temperature.gpu,utilization.gpu,utilization.memory --format=csv,noheader,nounits
        else
          echo "nvidia-smi not available"
        fi
        echo ""
        
        echo "GPU device files:"
        ls -la /dev/nvidia* 2>/dev/null || echo "No NVIDIA devices found"
      '')
    ];
    
    # Prometheus scrape configuration for GPU metrics
    services.prometheus = mkIf (cfg.mode == "server" || cfg.mode == "standalone") {
      extraConfig = ''
        - job_name: 'gpu-exporter'
          static_configs:
            - targets: ['razer:${toString cfg.network.gpuExporterPort}', 'p510:${toString cfg.network.gpuExporterPort}']
          scrape_interval: ${cfg.scrapeInterval}
          metrics_path: /metrics
      '';
    };
  };
}