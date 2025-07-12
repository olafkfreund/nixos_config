# Service Module Template
#
# This template is specifically for modules that manage systemd services
# with comprehensive configuration options, security hardening, and monitoring.
#
# Usage:
# 1. Copy to modules/services/SERVICE_NAME.nix
# 2. Replace PLACEHOLDER values
# 3. Add to modules/default.nix imports
# 4. Enable with: features.services.SERVICE_NAME = true;

{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.modules.services.SERVICE_NAME;
  
  # Service configuration file generation
  serviceConfigFile = pkgs.writeText "SERVICE_NAME.conf" ''
    # Generated configuration for SERVICE_NAME
    ${concatStringsSep "\n" (mapAttrsToList (name: value: "${name} = ${toString value}") cfg.settings)}
  '';
  
  # Service user/group management
  serviceUser = cfg.user;
  serviceGroup = cfg.group;
in {
  options.modules.services.SERVICE_NAME = {
    enable = mkEnableOption "SERVICE_NAME service";

    # Service configuration
    package = mkOption {
      type = types.package;
      default = pkgs.SERVICE_PACKAGE;
      description = "The SERVICE_NAME package to use";
    };

    # Network configuration
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host address to bind to";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on";
    };

    # Service settings
    settings = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "SERVICE_NAME configuration settings";
      example = literalExpression ''
        {
          log_level = "info";
          max_connections = "100";
        }
      '';
    };

    # User/Group configuration
    user = mkOption {
      type = types.str;
      default = "SERVICE_NAME";
      description = "User to run SERVICE_NAME as";
    };

    group = mkOption {
      type = types.str;
      default = "SERVICE_NAME";
      description = "Group to run SERVICE_NAME as";
    };

    # Data directory
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/SERVICE_NAME";
      description = "Data directory for SERVICE_NAME";
    };

    # Security options
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall port for SERVICE_NAME";
    };

    # Advanced options
    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional command line arguments";
      example = [ "--verbose" "--debug" ];
    };

    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Environment variables for the service";
      example = literalExpression ''
        {
          SERVICE_ENV = "production";
          LOG_LEVEL = "info";
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # System packages
    environment.systemPackages = [ cfg.package ];

    # Create service user and group
    users.users.${serviceUser} = mkIf (serviceUser == "SERVICE_NAME") {
      isSystemUser = true;
      group = serviceGroup;
      description = "SERVICE_NAME service user";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${serviceGroup} = mkIf (serviceGroup == "SERVICE_NAME") {};

    # Data directory setup
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${serviceUser} ${serviceGroup} -"
      "d ${cfg.dataDir}/logs 0755 ${serviceUser} ${serviceGroup} -"
      "d ${cfg.dataDir}/config 0755 ${serviceUser} ${serviceGroup} -"
    ];

    # Main service configuration
    systemd.services.SERVICE_NAME = {
      description = "SERVICE_DESCRIPTION";
      documentation = [ "https://docs.example.com/SERVICE_NAME" ];
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = serviceUser;
        Group = serviceGroup;
        WorkingDirectory = cfg.dataDir;
        
        # Command to run
        ExecStart = concatStringsSep " " ([
          "${cfg.package}/bin/SERVICE_NAME"
          "--config ${serviceConfigFile}"
          "--host ${cfg.host}"
          "--port ${toString cfg.port}"
          "--data-dir ${cfg.dataDir}"
        ] ++ cfg.extraArgs);

        # Restart configuration
        Restart = "always";
        RestartSec = "10s";
        StartLimitBurst = 3;
        StartLimitIntervalSec = "30s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        ReadOnlyPaths = [ serviceConfigFile ];
        
        # Additional security options
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        
        # Resource limits
        LimitNOFILE = 65536;
        MemoryMax = "1G";
        
        # Environment variables
        Environment = mapAttrsToList (name: value: "${name}=${value}") cfg.environmentVariables;
      };

      # Pre-start script for setup
      preStart = ''
        # Ensure configuration file is properly linked
        ln -sf ${serviceConfigFile} ${cfg.dataDir}/config/SERVICE_NAME.conf
        
        # Set proper permissions
        chown -R ${serviceUser}:${serviceGroup} ${cfg.dataDir}
        chmod 755 ${cfg.dataDir}
      '';

      # Post-start verification
      postStart = ''
        # Wait for service to be ready
        timeout=30
        while [ $timeout -gt 0 ]; do
          if ${pkgs.curl}/bin/curl -f -s "http://${cfg.host}:${toString cfg.port}/health" >/dev/null 2>&1; then
            echo "SERVICE_NAME is ready"
            exit 0
          fi
          sleep 1
          timeout=$((timeout - 1))
        done
        echo "SERVICE_NAME failed to start within 30 seconds"
        exit 1
      '';
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    # Log rotation
    services.logrotate.settings.SERVICE_NAME = {
      files = [ "${cfg.dataDir}/logs/*.log" ];
      frequency = "daily";
      rotate = 30;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "644 ${serviceUser} ${serviceGroup}";
      postrotate = ''
        systemctl reload SERVICE_NAME
      '';
    };

    # Monitoring integration (if available)
    # services.prometheus.exporters.SERVICE_NAME = mkIf config.services.prometheus.enable {
    #   enable = true;
    #   port = cfg.port + 1000;  # Metrics port
    #   listenAddress = cfg.host;
    # };

    # Validation assertions
    assertions = [
      {
        assertion = cfg.port > 1024 || serviceUser == "root";
        message = "SERVICE_NAME: ports <= 1024 require root privileges";
      }
      {
        assertion = cfg.host != "0.0.0.0" || cfg.openFirewall;
        message = "SERVICE_NAME: binding to 0.0.0.0 requires openFirewall = true";
      }
    ];

    # Helpful warnings
    warnings = [
      (mkIf (cfg.host == "0.0.0.0" && !cfg.openFirewall) ''
        SERVICE_NAME is configured to bind to all interfaces (0.0.0.0) 
        but firewall is not opened. Service may not be accessible externally.
      '')
      (mkIf (serviceUser == "root") ''
        SERVICE_NAME is running as root. Consider using a dedicated user for better security.
      '')
    ];
  };
}