{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.ai.providers.qwen;
in {
  options.ai.providers.qwen = {
    enabled = mkEnableOption "Qwen AI provider support";
    
    apiKeyFile = mkOption {
      type = types.str;
      default = "/run/agenix/api-qwen";
      description = "Path to the Qwen API key file";
    };
    
    baseUrl = mkOption {
      type = types.str;
      default = "https://dashscope.aliyuncs.com/api/v1";
      description = "Qwen API base URL";
    };
    
    model = mkOption {
      type = types.str;
      default = "qwen-turbo";
      description = "Default Qwen model to use";
    };
    
    timeout = mkOption {
      type = types.int;
      default = 30;
      description = "Request timeout in seconds";
    };
    
    maxRetries = mkOption {
      type = types.int;
      default = 3;
      description = "Maximum number of retry attempts";
    };
  };

  config = mkIf cfg.enabled {
    # Environment variables for Qwen API integration
    environment.sessionVariables = {
      QWEN_API_KEY_FILE = cfg.apiKeyFile;
      QWEN_BASE_URL = cfg.baseUrl;
      QWEN_MODEL = cfg.model;
    };

    # Install Qwen CLI tools if available
    environment.systemPackages = with pkgs; [
      # Add qwen-code when the package is working
      # qwen-code
    ];

    # Service for Qwen API health monitoring
    systemd.services.qwen-health-check = {
      description = "Qwen API Health Check";
      serviceConfig = {
        Type = "oneshot";
        User = "nobody";
        Group = "nogroup";
        ExecStart = pkgs.writeScript "qwen-health-check" ''
          #!/bin/bash
          set -eu
          
          if [ ! -f "${cfg.apiKeyFile}" ]; then
            echo "❌ Qwen API key file not found: ${cfg.apiKeyFile}"
            exit 1
          fi
          
          # Basic connectivity test (without exposing API key)
          if command -v curl >/dev/null 2>&1; then
            if curl -s --connect-timeout 10 "${cfg.baseUrl}" >/dev/null; then
              echo "✅ Qwen API endpoint accessible"
            else
              echo "⚠️ Qwen API endpoint not accessible"
              exit 1
            fi
          else
            echo "⚠️ curl not available for health check"
          fi
          
          echo "✅ Qwen provider configuration valid"
        '';
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    # Timer for periodic health checks
    systemd.timers.qwen-health-check = {
      description = "Qwen API Health Check Timer";
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
      wantedBy = ["timers.target"];
    };
  };
}