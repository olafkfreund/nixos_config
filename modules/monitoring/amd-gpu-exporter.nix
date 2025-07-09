{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.monitoring;
  
  # Import our custom AMD SMI exporter package
  # amd-smi-exporter = pkgs.amd-smi-exporter;  # Commented out until package build issues resolved
in {
  config = mkIf (cfg.enable && cfg.features.amdGpuMetrics) {
    # AMD GPU Exporter service - TEMPORARILY DISABLED until package build issues resolved
    # systemd.services.amd-gpu-exporter = {
    #   description = "AMD GPU Prometheus Exporter";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   
    #   serviceConfig = {
    #     Type = "simple";
    #     ExecStart = "${amd-smi-exporter}/bin/amd_smi_exporter --web.listen-address=:${toString cfg.network.amdGpuExporterPort} --web.telemetry-path=/metrics";
    #     Restart = "on-failure";
    #     RestartSec = "5s";
    #     User = "amd-gpu-exporter";
    #     Group = "amd-gpu-exporter";
    #     
    #     # Security hardening
    #     NoNewPrivileges = true;
    #     ProtectSystem = "strict";
    #     ProtectHome = true;
    #     PrivateTmp = true;
    #     PrivateDevices = false;  # Need access to GPU devices
    #     ProtectKernelTunables = true;
    #     ProtectKernelModules = true;
    #     ProtectControlGroups = true;
    #     RestrictSUIDSGID = true;
    #     RestrictRealtime = true;
    #     RestrictNamespaces = true;
    #     LockPersonality = true;
    #     
    #     # Memory and CPU limits
    #     MemoryMax = "64M";
    #     CPUQuota = "10%";
    #     
    #     # Environment for ROCm
    #     Environment = [
    #       "ROCM_PATH=${pkgs.rocmPackages.rocm-smi}"
    #       "PATH=${lib.makeBinPath [ pkgs.rocmPackages.rocm-smi pkgs.rocmPackages.rocm-runtime ]}"
    #     ];
    #   };
    # };
    
    # Create user for AMD GPU exporter - TEMPORARILY DISABLED
    # users.groups.amd-gpu-exporter = {};
    # users.users.amd-gpu-exporter = {
    #   isSystemUser = true;
    #   group = "amd-gpu-exporter";
    #   description = "AMD GPU Exporter service user";
    #   extraGroups = [ "video" "render" ];  # Access to GPU devices
    # };
    
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
    
    # Prometheus scrape configuration for AMD GPU metrics - TEMPORARILY DISABLED
    # services.prometheus = mkIf (cfg.mode == "server" || cfg.mode == "standalone") {
    #   extraConfig = ''
    #     - job_name: 'amd-gpu-exporter'
    #       static_configs:
    #         - targets: ['p620:${toString cfg.network.amdGpuExporterPort}']
    #       scrape_interval: ${cfg.scrapeInterval}
    #       metrics_path: /metrics
    #   '';
    # };
    
    # Ensure ROCm is available for AMD GPU systems
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        rocmPackages.rocm-opencl-icd
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