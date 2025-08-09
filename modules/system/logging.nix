# Logging configuration for reduced noise
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.system.logging;
in
{
  options.system.logging = {
    enableFiltering = mkEnableOption "Enable log filtering for noise reduction";

    filterRules = mkOption {
      type = types.listOf types.str;
      default = [ ];
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

    # Configure systemd-journald to filter container logs
    systemd.services.journal-filter = {
      description = "Journal Log Filter for Container Noise";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "setup-journal-filter" ''
          # Create custom journal namespace for filtered logs
          mkdir -p /var/log/journal-filtered

          # Set up log filtering via systemd-journald
          systemctl restart systemd-journald
        '';
      };
    };

    # Configure Docker daemon for better logging
    virtualisation.docker.daemon.settings = {
      log-driver = "journald";
      log-opts = {
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
