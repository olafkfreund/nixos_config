{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mdatp;
in
{
  options.services.mdatp = {
    enable = mkEnableOption "Microsoft Defender for Endpoint";

    package = mkOption {
      type = types.package;
      default = pkgs.mdatp;
      defaultText = literalExpression "pkgs.mdatp";
      description = ''
        The Microsoft Defender for Endpoint package to use.
      '';
    };

    onboardingFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = literalExpression "/run/agenix/mdatp-onboarding.json";
      description = ''
        Path to the Microsoft Defender onboarding JSON file.

        This file must be obtained from the Microsoft Defender portal
        (https://security.microsoft.com) under Settings > Endpoints > Onboarding.

        It is recommended to store this file using agenix for security:
        ```nix
        age.secrets."mdatp-onboarding" = {
          file = ../secrets/mdatp-onboarding.json.age;
          path = "/etc/opt/microsoft/mdatp/mdatp_onboard.json";
          mode = "0600";
        };
        ```
      '';
    };

    managedSettings = mkOption {
      type = types.nullOr (types.attrsOf types.anything);
      default = null;
      example = literalExpression ''
        {
          antivirusEngine = {
            enforcementLevel = "real_time";
            scanAfterDefinitionUpdate = true;
            scanArchives = true;
            maximumOnDemandScanThreads = 2;
          };
          cloudService = {
            enabled = true;
            diagnosticLevel = "optional";
            automaticDefinitionUpdateEnabled = true;
          };
        }
      '';
      description = ''
        Managed configuration settings for Microsoft Defender.

        These settings will be written to `/etc/opt/microsoft/mdatp/managed/mdatp_managed.json`.

        See the official documentation for available options:
        https://learn.microsoft.com/en-us/defender-endpoint/linux-preferences
      '';
    };

    logLevel = mkOption {
      type = types.enum [ "error" "warning" "info" "verbose" "debug" ];
      default = "info";
      description = ''
        Logging level for Microsoft Defender service.

        Available levels:
        - error: Only critical errors
        - warning: Errors and warnings
        - info: Normal operation information (default)
        - verbose: Detailed operation logs
        - debug: Full debugging information
      '';
    };

    autoUpdate = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable automatic definition updates.

        When enabled, Microsoft Defender will automatically download
        and install the latest threat definitions.
      '';
    };

    enableNetworkProtection = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable network protection features.

        This requires the mde-netfilter kernel module and may impact
        network performance. Disable if you experience network issues.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Assertions for required configuration
    assertions = [
      {
        assertion = cfg.onboardingFile != null;
        message = ''
          services.mdatp.onboardingFile must be set to onboard this host.

          Obtain the onboarding file from Microsoft Defender portal:
          1. Navigate to https://security.microsoft.com
          2. Go to Settings > Endpoints > Onboarding
          3. Select "Linux Server" as the operating system
          4. Download the onboarding package
          5. Configure the path in your NixOS configuration

          Example:
            services.mdatp.onboardingFile = /run/agenix/mdatp-onboarding.json;
        '';
      }
      {
        assertion = config.systemd.package != null;
        message = "Microsoft Defender requires systemd to be enabled.";
      }
    ];

    # Install the mdatp package
    environment.systemPackages = [ cfg.package ];

    # Create required system user and group
    users.users.mdatp = {
      isSystemUser = true;
      group = "mdatp";
      description = "Microsoft Defender for Endpoint";
      home = "/var/opt/microsoft/mdatp";
    };

    users.groups.mdatp = { };

    # Set up required directories with proper permissions
    systemd.tmpfiles.rules = [
      # Main configuration directory
      "d /etc/opt/microsoft 0755 root root -"
      "d /etc/opt/microsoft/mdatp 0755 root root -"
      "d /etc/opt/microsoft/mdatp/managed 0755 root root -"

      # Application directory
      "d /opt/microsoft 0755 root root -"
      "d /opt/microsoft/mdatp 0755 root root -"

      # State and data directory
      "d /var/opt/microsoft 0755 root root -"
      "d /var/opt/microsoft/mdatp 0750 mdatp mdatp -"

      # Log directory
      "d /var/log/microsoft 0755 root root -"
      "d /var/log/microsoft/mdatp 0750 mdatp mdatp -"
    ];

    # Write managed settings if configured
    environment.etc = mkMerge [
      (mkIf (cfg.managedSettings != null) {
        "opt/microsoft/mdatp/managed/mdatp_managed.json" = {
          text = builtins.toJSON cfg.managedSettings;
          mode = "0644";
        };
      })
      (mkIf (cfg.onboardingFile != null) {
        "opt/microsoft/mdatp/mdatp_onboard.json" = {
          source = cfg.onboardingFile;
          mode = "0600";
        };
      })
    ];

    # Bind mount the FHS environment to /opt/microsoft/mdatp
    fileSystems."/opt/microsoft/mdatp" = {
      device = "${cfg.package}/opt/microsoft/mdatp";
      options = [ "bind" "ro" ];
    };

    # Main systemd service
    systemd.services.mdatp = {
      description = "Microsoft Defender for Endpoint";
      documentation = [ "https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-endpoint-linux" ];

      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Service configuration with security hardening
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/mdatp-daemon --log-level ${cfg.logLevel}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

        # User and group
        User = "root"; # MDE requires root for system protection
        Group = "mdatp";

        # Restart policy
        Restart = "on-failure";
        RestartSec = "10s";
        StartLimitBurst = 5;
        StartLimitInterval = "5min";

        # Timeout configuration
        TimeoutStartSec = "60s";
        TimeoutStopSec = "30s";

        # Security hardening (balanced with MDE requirements)
        # Note: MDE requires extensive system access for endpoint protection
        ProtectSystem = "false"; # MDE needs write access to system
        ProtectHome = "false"; # MDE needs to scan user files
        PrivateTmp = false; # MDE needs access to system tmp
        NoNewPrivileges = false; # MDE may need privilege escalation

        # Minimal hardening that doesn't break MDE
        ProtectKernelTunables = false; # MDE may need to modify kernel parameters
        ProtectControlGroups = true;
        RestrictRealtime = true;
        RestrictNamespaces = false; # MDE may use namespaces
        LockPersonality = true;
        RestrictSUIDSGID = false; # MDE may need SUID/SGID

        # Resource limits
        MemoryMax = "2G";
        TasksMax = 1000;

        # Logging
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "mdatp";
      };

      # Environment variables
      environment = {
        MDATP_LOG_LEVEL = cfg.logLevel;
        MDATP_HOME = "/var/opt/microsoft/mdatp";
      };

      # Pre-start checks
      preStart = ''
        # Verify onboarding file exists
        if [ ! -f /etc/opt/microsoft/mdatp/mdatp_onboard.json ]; then
          echo "ERROR: Onboarding file not found at /etc/opt/microsoft/mdatp/mdatp_onboard.json"
          echo "Please configure services.mdatp.onboardingFile"
          exit 1
        fi

        # Verify onboarding file is valid JSON
        if ! ${pkgs.jq}/bin/jq empty /etc/opt/microsoft/mdatp/mdatp_onboard.json 2>/dev/null; then
          echo "ERROR: Onboarding file is not valid JSON"
          exit 1
        fi

        # Create required directories if they don't exist
        mkdir -p /var/opt/microsoft/mdatp
        mkdir -p /var/log/microsoft/mdatp

        # Set proper ownership
        chown mdatp:mdatp /var/opt/microsoft/mdatp
        chown mdatp:mdatp /var/log/microsoft/mdatp

        echo "Microsoft Defender for Endpoint pre-start checks passed"
      '';

      # Post-start health check
      postStart = ''
        # Wait for service to initialize
        sleep 5

        # Check if daemon is responding
        if ${cfg.package}/bin/mdatp health --field healthy 2>/dev/null | grep -q "true"; then
          echo "Microsoft Defender is healthy"
        else
          echo "WARNING: Microsoft Defender health check failed"
          echo "Run 'mdatp health' to diagnose issues"
        fi
      '';
    };

    # Optional: Network protection service
    systemd.services.mdatp-netfilter = mkIf cfg.enableNetworkProtection {
      description = "Microsoft Defender Network Protection";
      after = [ "mdatp.service" ];
      requires = [ "mdatp.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.kmod}/bin/modprobe mde-netfilter";
        ExecStop = "${pkgs.kmod}/bin/modprobe -r mde-netfilter";

        # Security hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    # Firewall configuration for Microsoft Defender endpoints
    networking.firewall.extraCommands = ''
      # Allow outbound connections to Microsoft Defender endpoints
      # See: https://learn.microsoft.com/en-us/defender-endpoint/configure-proxy-internet

      # Note: MDE requires HTTPS (443) access to:
      # - *.endpoint.security.microsoft.com
      # - *.events.data.microsoft.com
      # - *.blob.core.windows.net
      # These are allowed by default outbound firewall rules
    '';

    # Add helpful CLI aliases
    environment.shellAliases = {
      mdatp-health = "${cfg.package}/bin/mdatp health";
      mdatp-scan = "${cfg.package}/bin/mdatp scan quick";
      mdatp-status = "systemctl status mdatp";
      mdatp-logs = "journalctl -u mdatp -f";
    };

    # Security warnings in system message of the day
    users.motd = mkAfter ''

      Microsoft Defender for Endpoint is active on this system.
      - Service status: systemctl status mdatp
      - Health check: mdatp health
      - Quick scan: mdatp scan quick
      - View logs: journalctl -u mdatp -f

      Documentation: https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-endpoint-linux
    '';
  };

  meta = {
    maintainers = with lib.maintainers; [ ];
    doc = ./mdatp.md;
  };
}
