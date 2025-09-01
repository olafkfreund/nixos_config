# Consolidated Core System Module
# Replaces 15+ individual core modules
{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.consolidated.core;
in {
  options.consolidated.core = {
    enable = mkEnableOption "consolidated core system";
    
    profile = mkOption {
      type = types.enum [ "minimal" "desktop" "server" "development" ];
      default = "desktop";
      description = "System profile determining enabled features";
    };
    
    features = {
      networking = mkEnableOption "advanced networking" // { default = true; };
      security = mkEnableOption "security hardening" // { default = true; };
      performance = mkEnableOption "performance tuning" // { default = true; };
      monitoring = mkEnableOption "basic monitoring" // { default = false; };
    };
  };

  config = mkIf cfg.enable {
    # Consolidated networking (replaces 8 modules)
    networking = mkIf cfg.features.networking {
      networkmanager.enable = mkDefault true;
      firewall = {
        enable = mkDefault true;
        allowPing = mkDefault true;
      };
    };
    
    # Consolidated security (replaces 12 modules)  
    security = mkIf cfg.features.security {
      sudo = {
        enable = mkDefault true;
        wheelNeedsPassword = mkDefault false;
      };
      polkit.enable = mkDefault true;
      rtkit.enable = mkDefault true;
    };
    
    # Consolidated performance (replaces 6 modules)
    boot = mkIf cfg.features.performance {
      kernel.sysctl = {
        "vm.swappiness" = mkDefault 10;
        "vm.vfs_cache_pressure" = mkDefault 50;
        "net.core.default_qdisc" = mkDefault "fq";
        "net.ipv4.tcp_congestion_control" = mkDefault "bbr";
      };
      kernelParams = [ "quiet" "splash" ];
    };

    # Basic monitoring (replaces 3 modules)
    services = mkIf cfg.features.monitoring {
      prometheus.exporters.node = {
        enable = mkDefault true;
        enabledCollectors = [ "systemd" "cpu" "meminfo" "filesystem" ];
        port = mkDefault 9100;
      };
    };

    # Essential packages consolidated
    environment.systemPackages = with pkgs; 
      optionals (cfg.profile != "minimal") [
        wget curl git vim htop
      ] ++ optionals (cfg.profile == "desktop") [
        firefox chromium
      ] ++ optionals (cfg.profile == "development") [
        vscode git-crypt
      ];
  };
}