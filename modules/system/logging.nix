# Logging configuration for reduced noise
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.system.logging;
in {
  options.system.logging = {
    enableFiltering = mkEnableOption "Enable log filtering for noise reduction";
    
    filterRules = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of log filtering rules";
    };
  };

  config = mkIf cfg.enableFiltering {
    # Configure journald to filter noisy logs
    services.journald.extraConfig = ''
      # Set maximum log level for containers
      MaxLevelStore=info
      MaxLevelSyslog=info
      MaxLevelConsole=warning
      
      # Rate limiting for high-volume logs
      RateLimitInterval=30s
      RateLimitBurst=10000
      
      # Storage optimization
      SystemMaxUse=1G
      SystemMaxFileSize=128M
      RuntimeMaxUse=512M
      RuntimeMaxFileSize=64M
      
      # Retention policy
      MaxRetentionSec=7day
      MaxFileSec=1day
    '';

    # Create rsyslog configuration for container log filtering
    services.rsyslog = {
      enable = true;
      extraConfig = ''
        # Filter out health check spam from containers
        :msg, contains, "router dispatching GET /health" stop
        :msg, contains, "router jsonParser  : /health" stop
        :msg, contains, "body-parser:json skip empty body" stop
        :msg, contains, "GET /health" stop
        :msg, contains, "health check" stop
        
        # Filter out other common noise
        :msg, contains, "debug:" stop
        :msg, contains, "verbose:" stop
        :msg, contains, "trace:" stop
        
        # Filter container connection logs
        :msg, contains, "connection established" stop
        :msg, contains, "connection closed" stop
      '';
    };

    # Configure Docker daemon for better logging
    virtualisation.docker.daemon.settings = {
      log-driver = "journald";
      log-opts = {
        "max-size" = "10m";
        "max-file" = "5";
        "labels" = "service";
      };
    };
    
    # Environment variables for better log control
    environment.variables = {
      # Reduce Docker log verbosity
      DOCKER_LOG_LEVEL = "warn";
      
      # Node.js applications log level
      NODE_ENV = "production";
      LOG_LEVEL = "info";
    };
  };
}