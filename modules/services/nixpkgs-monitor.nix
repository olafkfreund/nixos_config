# NixOS Nixpkgs Update Monitor Service
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixpkgs-monitor;

  # Create the monitoring script
  monitorScript = pkgs.writeScriptBin "nixpkgs-monitor" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Configuration
    SCRIPT_DIR="${config.users.users.${cfg.user}.home}/.config/nixos/scripts"
    LOG_FILE="/var/log/nixpkgs-monitor.log"
    
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }
    
    log "🔍 Starting nixpkgs update check..."
    
    # Run the update checker
    if "${cfg.scriptPath}" --update --channel "${cfg.channel}" --format "${cfg.format}"; then
        log "✅ Update check completed successfully"
    else
        log "❌ Update check failed"
        exit 1
    fi
    
    # Optional: Send notification
    ${optionalString cfg.notifications.enable ''
      if command -v notify-send >/dev/null 2>&1; then
          notify-send "NixOS Updates" "Package update check completed" --icon=software-update-available
      fi
    ''}
  '';

in
{
  options.services.nixpkgs-monitor = {
    enable = mkEnableOption "Enable automatic nixpkgs update monitoring";

    user = mkOption {
      type = types.str;
      default = "olafkfreund";
      description = "User to run the monitor service as";
    };

    scriptPath = mkOption {
      type = types.path;
      default = "${config.users.users.${cfg.user}.home}/.config/nixos/scripts/nixpkgs-update-checker.sh";
      description = "Path to the update checker script";
    };

    channel = mkOption {
      type = types.str;
      default = "nixos-unstable";
      description = "Nixpkgs channel to monitor";
    };

    format = mkOption {
      type = types.enum [ "simple" "detailed" "json" ];
      default = "detailed";
      description = "Output format for updates";
    };

    schedule = mkOption {
      type = types.str;
      default = "*:0/30"; # Every 30 minutes
      description = "Systemd timer schedule (systemd.time format)";
    };

    notifications = {
      enable = mkEnableOption "Enable desktop notifications";

      onUpdates = mkOption {
        type = types.bool;
        default = true;
        description = "Send notification when updates are found";
      };
    };

    logging = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable logging to /var/log/nixpkgs-monitor.log";
      };

      maxSize = mkOption {
        type = types.str;
        default = "10M";
        description = "Maximum log file size";
      };
    };
  };

  config = mkIf cfg.enable {
    # Install the monitoring script
    environment.systemPackages = [
      monitorScript
      pkgs.git
      pkgs.jq
      pkgs.curl
    ];

    # Create the systemd service
    systemd.services.nixpkgs-monitor = {
      description = "NixOS Nixpkgs Update Monitor";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = "users";
        ExecStart = "${monitorScript}/bin/nixpkgs-monitor";

        # Security settings
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        NoNewPrivileges = true;

        # Logging
        StandardOutput = mkIf cfg.logging.enable "journal";
        StandardError = mkIf cfg.logging.enable "journal";
      };
    };

    # Create the systemd timer
    systemd.timers.nixpkgs-monitor = {
      description = "Timer for NixOS Nixpkgs Update Monitor";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m"; # Random delay to avoid load spikes
      };
    };

    # Log rotation
    services.logrotate.settings.nixpkgs-monitor = mkIf cfg.logging.enable {
      "/var/log/nixpkgs-monitor.log" = {
        size = cfg.logging.maxSize;
        rotate = 5;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "644 ${cfg.user} users";
      };
    };

    # Create log directory
    systemd.tmpfiles.rules = mkIf cfg.logging.enable [
      "d /var/log 0755 root root -"
      "f /var/log/nixpkgs-monitor.log 0644 ${cfg.user} users -"
    ];
  };
}
