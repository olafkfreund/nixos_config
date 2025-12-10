{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.intune;
in
{
  options.features.intune = {
    enable = mkEnableOption "Microsoft Intune Company Portal";

    package = mkOption {
      type = types.package;
      default = pkgs.intune-portal;
      defaultText = literalExpression "pkgs.intune-portal";
      description = ''
        The Microsoft Intune Company Portal package to use.

        This defaults to our custom-built package with manual version control.
        Change the version by updating pkgs/intune-portal/default.nix and
        rebuilding the system.
      '';
      example = literalExpression "pkgs.intune-portal";
    };

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to automatically start the Intune Portal service on login.

        When enabled, the intune-portal service will start with the user session.
        When disabled, you must manually launch intune-portal from the application menu.
      '';
    };

    enableDesktopIntegration = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to install desktop integration files (.desktop files, system tray support).

        This makes Intune Portal available in application menus and provides
        system tray integration for enrollment status and notifications.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Install the Intune Portal package and required dependencies
    # Microsoft Edge is required for authentication workflows
    environment.systemPackages = with pkgs; [
      cfg.package
      openjdk11 # CRITICAL: OpenJDK 11 required for microsoft-identity-broker
      microsoft-edge # Required for Intune authentication workflows
    ];

    # PAM configuration for Intune authentication
    security.pam.services.intune = {
      text = ''
        auth required ${cfg.package}/lib/security/pam_intune.so
        account required ${cfg.package}/lib/security/pam_intune.so
      '';
    };

    # Systemd user service for Intune Portal
    systemd.user.services.intune-portal = mkIf cfg.autoStart {
      description = "Microsoft Intune Company Portal";
      documentation = [ "https://learn.microsoft.com/en-us/intune/intune-service/user-help/microsoft-intune-app-linux" ];

      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/intune-portal";
        Restart = "on-failure";
        RestartSec = 5;

        # Security hardening following docs/PATTERNS.md
        # Note: DynamicUser cannot be used for user services
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;

        # Allow specific capabilities needed for network operations
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];

        # Restrict system calls
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        SystemCallArchitectures = "native";

        # Resource limits
        MemoryMax = "512M";
        TasksMax = 256;

        # Network access required for enrollment and compliance checks
        PrivateNetwork = false;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      };
    };

    # Systemd agent and daemon services
    systemd.user.services.intune-agent = {
      description = "Microsoft Intune Agent";
      documentation = [ "https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/deployment-guide-platform-linux" ];

      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/intune-agent";
        Restart = "on-failure";
        RestartSec = 10;

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;

        # Network access required
        PrivateNetwork = false;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];

        # Resource limits
        MemoryMax = "256M";
        TasksMax = 128;
      };
    };

    # Validation assertions
    assertions = [
      {
        assertion = cfg.enable -> (builtins.elem pkgs.microsoft-edge config.environment.systemPackages);
        message = ''
          features.intune.enable requires Microsoft Edge browser for authentication.
          The module automatically installs it via environment.systemPackages.
        '';
      }
    ];

    # Warnings for known issues
    warnings = lib.optionals cfg.enable [
      ''
        Microsoft Intune Portal officially supports GNOME desktop environment.
        If you encounter issues with other desktop environments, consider testing
        with GNOME or enabling XWayland compatibility for your compositor.
      ''
    ] ++ lib.optionals (cfg.enable && !cfg.autoStart) [
      ''
        Intune Portal auto-start is disabled. You will need to manually launch
        intune-portal from the application menu after system boot.
      ''
    ];
  };

  meta = {
    maintainers = with lib.maintainers; [ ];
  };
}
