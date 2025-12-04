{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nixos-update-checker;

  # Update checker script
  checkUpdatesScript = pkgs.writeShellScript "nixos-check-updates" ''
    set -euo pipefail

    STATE_DIR="''${STATE_DIRECTORY:-/var/lib/nixos-update-checker}"
    UPDATES_FILE="$STATE_DIR/updates-available"
    FLAKE_LOCK_CACHE="$STATE_DIR/flake.lock.cache"
    LAST_CHECK_FILE="$STATE_DIR/last-check"
    LOG_FILE="$STATE_DIR/check.log"

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }

    log "Starting NixOS update check..."

    # Record check time
    date '+%Y-%m-%d %H:%M:%S' > "$LAST_CHECK_FILE"

    # Create temporary directory for flake operations
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    # Verify flake directory exists
    if [ ! -f "${cfg.flakeDir}/flake.lock" ]; then
      log "ERROR: No flake.lock found at ${cfg.flakeDir}"
      exit 1
    fi

    # Check for updates by comparing flake.lock hash
    cd "${cfg.flakeDir}"
    log "Checking for flake input updates..."

    # Get current flake.lock hash
    CURRENT_HASH=$(sha256sum "${cfg.flakeDir}/flake.lock" | cut -d' ' -f1)
    log "Current flake.lock hash: $CURRENT_HASH"

    # Check if we have a cached hash
    if [ -f "$FLAKE_LOCK_CACHE" ]; then
      CACHED_HASH=$(cat "$FLAKE_LOCK_CACHE")
      log "Cached flake.lock hash: $CACHED_HASH"

      if [ "$CURRENT_HASH" = "$CACHED_HASH" ]; then
        log "No updates available (flake.lock unchanged)"
        rm -f "$UPDATES_FILE"
        exit 0
      fi

      log "Flake inputs have changed since last check"
    else
      log "First check - establishing baseline"
    fi

    # Save current hash
    echo "$CURRENT_HASH" > "$FLAKE_LOCK_CACHE"

      # Create updates notification
      {
        echo "NixOS Updates Available"
        echo "======================"
        echo "Checked: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Flake inputs have been updated."
        echo ""
        echo "To test updates: nixos-upgrade-test"
        echo "To apply updates: nixos-system-upgrade"
        echo ""
        echo "Run 'nixos-check-updates --details' for more information."
      } > "$UPDATES_FILE"

      log "Updates available! Notification created at $UPDATES_FILE"

      # Update MOTD if enabled
      ${optionalString cfg.enableMotd ''
        if [ -d /etc/motd.d ]; then
          ln -sf "$UPDATES_FILE" /etc/motd.d/50-nixos-updates
          log "MOTD updated"
        fi
      ''}
  '';

  # Test upgrade script (nixos-rebuild test)
  testUpgradeScript = pkgs.writeShellScript "nixos-upgrade-test" ''
    set -euo pipefail

    echo "=== NixOS Update Test ==="
    echo ""
    echo "This will build and test the new configuration without making it permanent."
    echo "Changes will be lost on reboot."
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi

    echo ""
    echo "Updating flake inputs..."
    cd "${cfg.flakeDir}"
    ${pkgs.nix}/bin/nix flake update

    echo ""
    echo "Building new configuration..."
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild test --flake "${cfg.flakeDir}" --use-remote-sudo

    echo ""
    echo "✅ Configuration tested successfully!"
    echo ""
    echo "The new configuration is now active temporarily."
    echo "To make it permanent, run: nixos-system-upgrade"
    echo "To revert, simply reboot."
  '';

  # System upgrade script (nixos-rebuild switch)
  systemUpgradeScript = pkgs.writeShellScript "nixos-system-upgrade" ''
    set -euo pipefail

    echo "=== NixOS System Upgrade ==="
    echo ""
    echo "⚠️  WARNING: This will permanently update your system!"
    echo ""
    echo "This will:"
    echo "  1. Update all flake inputs"
    echo "  2. Build the new configuration"
    echo "  3. Switch to the new configuration (permanent)"
    echo "  4. Create a new boot entry"
    echo ""
    read -p "Are you sure you want to continue? (yes/N) " -r
    echo

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      echo "Aborted."
      exit 0
    fi

    echo ""
    echo "Updating flake inputs..."
    cd "${cfg.flakeDir}"
    ${pkgs.nix}/bin/nix flake update

    echo ""
    echo "Building and switching to new configuration..."
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "${cfg.flakeDir}" --use-remote-sudo

    echo ""
    echo "✅ System upgraded successfully!"
    echo ""
    echo "The new configuration is now active and will persist after reboot."
    echo "You can rollback to the previous generation with: nixos-rebuild --rollback switch"

    # Clear updates notification
    rm -f /var/lib/nixos-update-checker/updates-available
    rm -f /etc/motd.d/50-nixos-updates 2>/dev/null || true

    echo ""
    echo "Update notification cleared."
  '';

in
{
  options.services.nixos-update-checker = {
    enable = mkEnableOption "NixOS update checker service";

    flakeDir = mkOption {
      type = types.path;
      default = "/home/olafkfreund/.config/nixos";
      description = "Path to the flake directory to check for updates";
    };

    checkInterval = mkOption {
      type = types.str;
      default = "monthly";
      example = "weekly";
      description = ''
        How often to check for updates. Uses systemd timer format.
        Common values: daily, weekly, monthly
      '';
    };

    enableMotd = mkOption {
      type = types.bool;
      default = true;
      description = "Enable MOTD (Message of the Day) notifications for available updates";
    };

    user = mkOption {
      type = types.str;
      default = "nixos-update-checker";
      description = "User to run the update checker service as";
    };

    group = mkOption {
      type = types.str;
      default = "nixos-update-checker";
      description = "Group for the update checker service";
    };
  };

  config = mkIf cfg.enable {
    # User and group for the service
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      description = "NixOS update checker service user";
    };

    users.groups.${cfg.group} = { };

    # CLI commands
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "nixos-check-updates" ''
        if [ "$1" = "--details" ]; then
          echo "=== NixOS Update Checker Status ==="
          echo ""

          if [ -f /var/lib/nixos-update-checker/last-check ]; then
            echo "Last check: $(cat /var/lib/nixos-update-checker/last-check)"
          else
            echo "Last check: Never"
          fi

          echo ""

          if [ -f /var/lib/nixos-update-checker/updates-available ]; then
            echo "Status: Updates available ✓"
            echo ""
            cat /var/lib/nixos-update-checker/updates-available
          else
            echo "Status: System up to date ✓"
          fi

          echo ""
          echo "Logs: /var/log/nixos-update-checker.log"
        else
          # Run the check now
          echo "Checking for NixOS updates..."
          sudo systemctl start nixos-update-checker.service
          sleep 2
          sudo journalctl -u nixos-update-checker.service -n 20 --no-pager
        fi
      '')

      (pkgs.writeShellScriptBin "nixos-upgrade-test" ''
        exec ${testUpgradeScript}
      '')

      (pkgs.writeShellScriptBin "nixos-system-upgrade" ''
        exec ${systemUpgradeScript}
      '')
    ];

    # Systemd service for checking updates
    systemd.services.nixos-update-checker = {
      description = "NixOS Update Checker";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;

        # Security hardening
        DynamicUser = false; # We need a stable user for state
        StateDirectory = "nixos-update-checker";

        # Sandboxing
        PrivateTmp = true;
        ProtectSystem = "strict";
        # Note: Can't use ProtectHome=true because we need to read the flake directory
        ProtectHome = "read-only"; # Allow read-only access to home
        ReadWritePaths = [
          "/var/lib/nixos-update-checker"
        ] ++ optional cfg.enableMotd "/etc/motd.d";

        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;

        # Resource limits
        MemoryMax = "512M";
        TasksMax = 100;

        # Timeout
        TimeoutSec = "10m";
      };

      script = toString checkUpdatesScript;
    };

    # Systemd timer for automatic checks
    systemd.timers.nixos-update-checker = {
      description = "NixOS Update Checker Timer";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.checkInterval;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Create MOTD directory if enabled
    environment.etc = mkIf cfg.enableMotd {
      "motd.d/.keep".text = "";
    };

    # Assertions
    # Note: Cannot check pathExists during evaluation due to sandbox
    # The service will fail at runtime if the path doesn't exist
    assertions = [ ];
  };

  meta = {
    maintainers = with maintainers; [ ];
    # Documentation available in README.md
  };
}
