# Logging configuration for reduced noise
{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types;
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

    # Docker's log driver is deliberately NOT set here.
    #
    # This block used to pin daemon.settings.log-driver = "journald", which
    # silently beat virtualisation.docker.logDriver: daemon.settings IS the
    # rendered daemon.json, so a raw entry here wins over the typed option no
    # matter what a host sets. #1412 switched logDriver to "local" to stop k3s
    # inside k3d filing ~94k INFO lines a boot as host-level errors, and this
    # line quietly reverted it — the built daemon.json still read "journald"
    # after that deploy.
    #
    # A module whose purpose is noise reduction should not be the thing forcing
    # every container's stderr into the journal. The driver now comes from
    # modules/containers/docker.nix, which owns Docker's configuration.

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
