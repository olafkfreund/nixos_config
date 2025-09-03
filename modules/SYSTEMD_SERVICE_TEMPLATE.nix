# Systemd Service Module Template
# Template for creating modules that manage systemd services
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.services.service-name;
in
{
  options.modules.services.service-name = {
    enable = mkEnableOption "service-name service";

    package = mkPackageOption pkgs "service-package" {
      description = "Package providing the service binary";
    };

    user = mkOption {
      type = types.str;
      default = "service-name";
      description = "User account under which the service runs";
    };

    group = mkOption {
      type = types.str;
      default = "service-name";
      description = "Group account under which the service runs";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/service-name";
      description = "Directory for storing service data";
    };

    settings = mkOption {
      type = with types; attrsOf anything;
      default = { };
      description = "Service configuration settings";
    };

    extraArgs = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Additional command-line arguments";
    };
  };

  config = mkIf cfg.enable {
    # Create system user and group
    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        createHome = true;
      };

      groups.${cfg.group} = { };
    };

    # Systemd service definition
    systemd.services.service-name = {
      description = "Service Name daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        # Security hardening
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
        WorkingDirectory = cfg.dataDir;
        ReadWritePaths = [ cfg.dataDir ];

        # Command
        ExecStart = "${cfg.package}/bin/service-binary ${concatStringsSep " " cfg.extraArgs}";

        # Restart policy
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # Configuration file generation (if needed)
    environment.etc."service-name/config.toml" = mkIf (cfg.settings != { }) {
      text = generators.toTOML { } cfg.settings;
      mode = "0644";
      user = cfg.user;
      group = cfg.group;
    };

    # Systemd tmpfiles for directory creation
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d /var/log/service-name 0755 ${cfg.user} ${cfg.group} -"
    ];

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
