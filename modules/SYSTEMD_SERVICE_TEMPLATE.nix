# Systemd Service Module Template
# Template for creating modules that manage systemd services
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption mkPackageOption types;
  cfg = config.features.service-name;
in
{
  options.features.service-name = {
    enable = mkEnableOption "service-name service";

    package = mkPackageOption pkgs "service-package" {
      description = "Package providing the service binary";
    };

    dataDir = mkOption {
      type = types.str;
      default = "service-name";
      description = "State directory name under /var/lib";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Service configuration settings";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional command-line arguments";
    };
  };

  config = mkIf cfg.enable {
    # Systemd service definition
    systemd.services.service-name = {
      description = "Service Name daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        # Security hardening
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;

        # Resource limits
        MemoryMax = "1G";
        TasksMax = 1000;

        # Working directory and data
        StateDirectory = cfg.dataDir;
        LogsDirectory = "service-name";
        WorkingDirectory = "/var/lib/${cfg.dataDir}";

        # Command
        ExecStart = "${cfg.package}/bin/service-binary ${lib.escapeShellArgs cfg.extraArgs}";

        # Restart policy
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # Configuration file generation (if needed)
    environment.etc."service-name/config.toml" = mkIf (cfg.settings != { }) {
      source = (pkgs.formats.toml { }).generate "config.toml" cfg.settings;
      mode = "0644";
    };

    # Network access if needed
    networking.firewall.allowedTCPPorts = mkIf (cfg.settings ? port) [
      cfg.settings.port
    ];

    # Assertions
    assertions = [
      {
        assertion = cfg.package != null;
        message = "service-name package must be specified";
      }
    ];
  };
}
