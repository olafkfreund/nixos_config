# Common NixOS Module Patterns and Code Snippets
#
# This file contains reusable code patterns and snippets commonly used
# in NixOS modules within this configuration.

{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  
  # ============================================================================
  # BASIC MODULE STRUCTURE PATTERN
  # ============================================================================
  
  # Standard module header
  /*
  {
    config,
    lib,
    pkgs,
    ...
  }:
  with lib; let
    cfg = config.modules.CATEGORY.MODULE_NAME;
  in {
    options.modules.CATEGORY.MODULE_NAME = {
      enable = mkEnableOption "MODULE_DESCRIPTION";
      # ... other options
    };
    
    config = mkIf cfg.enable {
      # ... configuration
    };
  }
  */

  # ============================================================================
  # COMMON OPTION PATTERNS
  # ============================================================================
  
  # String option with validation
  examples.stringOption = mkOption {
    type = types.str;
    default = "default-value";
    description = "Description of the option";
    example = "example-value";
  };
  
  # String option with enum validation
  examples.enumOption = mkOption {
    type = types.enum [ "option1" "option2" "option3" ];
    default = "option1";
    description = "Choose from predefined options";
  };
  
  # Package option
  examples.packageOption = mkOption {
    type = types.package;
    default = pkgs.example-package;
    description = "Package to use for this module";
  };
  
  # List of packages
  examples.packagesOption = mkOption {
    type = types.listOf types.package;
    default = [];
    description = "Additional packages to install";
    example = literalExpression "[ pkgs.package1 pkgs.package2 ]";
  };
  
  # List of strings
  examples.stringListOption = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "List of string values";
    example = [ "value1" "value2" "value3" ];
  };
  
  # Attribute set of strings
  examples.attrSetOption = mkOption {
    type = types.attrsOf types.str;
    default = {};
    description = "Key-value configuration";
    example = literalExpression ''
      {
        key1 = "value1";
        key2 = "value2";
      }
    '';
  };
  
  # Nullable option
  examples.nullableOption = mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Optional string value";
    example = "optional-value";
  };
  
  # Port number option
  examples.portOption = mkOption {
    type = types.port;
    default = 8080;
    description = "Port number to listen on";
  };
  
  # Path option
  examples.pathOption = mkOption {
    type = types.path;
    default = "/var/lib/example";
    description = "Directory path for data storage";
  };
  
  # Boolean option with default false
  examples.boolOption = mkOption {
    type = types.bool;
    default = false;
    description = "Enable optional feature";
  };
  
  # Submodule for complex options
  examples.submoduleOption = mkOption {
    type = types.submodule {
      options = {
        enable = mkEnableOption "feature";
        value = mkOption {
          type = types.str;
          default = "default";
          description = "Feature value";
        };
      };
    };
    default = {};
    description = "Complex configuration object";
  };

  # ============================================================================
  # SERVICE CONFIGURATION PATTERNS
  # ============================================================================
  
  # Basic systemd service
  examples.basicService = {
    systemd.services.example-service = {
      description = "Example Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "example-user";
        Group = "example-group";
        ExecStart = "${pkgs.example-package}/bin/example-command";
        Restart = "always";
        RestartSec = "10s";
      };
    };
  };
  
  # Service with security hardening
  examples.hardenedService = {
    systemd.services.hardened-service = {
      description = "Hardened Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "service-user";
        Group = "service-group";
        ExecStart = "${pkgs.service-package}/bin/service-command";
        
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
        ReadWritePaths = [ "/var/lib/service" ];
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
      };
    };
  };

  # ============================================================================
  # USER AND GROUP MANAGEMENT
  # ============================================================================
  
  # System user creation
  examples.systemUser = {
    users.users.example-user = {
      isSystemUser = true;
      group = "example-group";
      description = "Example service user";
      home = "/var/lib/example";
      createHome = true;
    };
    
    users.groups.example-group = {};
  };
  
  # Normal user with groups
  examples.normalUser = {
    users.users.example-user = {
      isNormalUser = true;
      description = "Example User";
      extraGroups = [ "wheel" "networkmanager" "docker" ];
      shell = pkgs.zsh;
      hashedPasswordFile = "/run/agenix/user-password-example";
    };
  };

  # ============================================================================
  # FILESYSTEM AND DIRECTORY PATTERNS
  # ============================================================================
  
  # Tmpfiles rules for directories
  examples.tmpfilesRules = {
    systemd.tmpfiles.rules = [
      "d /var/lib/example 0755 example-user example-group -"
      "d /var/log/example 0755 example-user example-group -"
      "d /etc/example 0755 root root -"
      "f /var/lib/example/config.conf 0644 example-user example-group -"
    ];
  };

  # ============================================================================
  # CONDITIONAL CONFIGURATION PATTERNS
  # ============================================================================
  
  # Simple conditional
  examples.simpleConditional = mkIf config.example.enable {
    environment.systemPackages = [ pkgs.example-package ];
  };
  
  # Multiple conditions
  examples.multipleConditions = mkIf (config.example.enable && config.example.feature) {
    services.example.extraConfig = "feature enabled";
  };
  
  # Optional lists
  examples.optionalList = 
    optional config.example.enableFeature1 pkgs.package1
    ++ optional config.example.enableFeature2 pkgs.package2
    ++ optionals config.example.enableFeatures [ pkgs.package3 pkgs.package4 ];
  
  # Conditional attributes
  examples.conditionalAttrs = {
    programs.example = {
      enable = true;
    } // optionalAttrs config.example.enableAdvanced {
      advancedConfig = true;
      extraOptions = [ "option1" "option2" ];
    };
  };

  # ============================================================================
  # VALIDATION PATTERNS
  # ============================================================================
  
  # Basic assertions
  examples.assertions = [
    {
      assertion = config.example.port > 1024;
      message = "Example: port must be greater than 1024";
    }
    {
      assertion = config.example.user != "root" || config.example.allowRoot;
      message = "Example: running as root requires allowRoot = true";
    }
    {
      assertion = config.example.enable -> config.networking.enable;
      message = "Example: requires networking to be enabled";
    }
  ];
  
  # Warnings
  examples.warnings = [
    (mkIf (config.example.enable && !config.example.secure) ''
      Example is running in insecure mode. Consider enabling security features.
    '')
    (mkIf (config.example.deprecated) ''
      Example: deprecated option used. Please migrate to the new configuration.
    '')
  ];

  # ============================================================================
  # CONFIGURATION FILE GENERATION
  # ============================================================================
  
  # JSON configuration file
  examples.jsonConfig = pkgs.writeText "example.json" (builtins.toJSON {
    setting1 = "value1";
    setting2 = config.example.setting2;
    nested = {
      option = true;
      list = [ 1 2 3 ];
    };
  });
  
  # INI-style configuration
  examples.iniConfig = pkgs.writeText "example.ini" ''
    [section1]
    key1 = value1
    key2 = ${config.example.value}
    
    [section2]
    enabled = true
    ${concatStringsSep "\n" (mapAttrsToList (k: v: "${k} = ${v}") config.example.settings)}
  '';
  
  # YAML configuration
  examples.yamlConfig = pkgs.writeText "example.yaml" (builtins.toJSON {
    # YAML content structure
    global = {
      setting = config.example.globalSetting;
    };
    features = config.example.features;
  });

  # ============================================================================
  # NETWORKING PATTERNS
  # ============================================================================
  
  # Firewall port opening
  examples.firewallPorts = {
    networking.firewall = {
      allowedTCPPorts = [ 80 443 8080 ];
      allowedUDPPorts = [ 53 67 68 ];
      allowedTCPPortRanges = [
        { from = 8000; to = 8999; }
      ];
    };
  };
  
  # Service-specific firewall
  examples.conditionalFirewall = {
    networking.firewall.allowedTCPPorts = mkIf config.example.openFirewall [ config.example.port ];
  };

  # ============================================================================
  # ENVIRONMENT AND SHELL PATTERNS
  # ============================================================================
  
  # Environment variables
  examples.environmentVars = {
    environment.variables = {
      EXAMPLE_HOME = "/etc/example";
      EXAMPLE_CONFIG = config.example.configPath;
    };
    
    environment.sessionVariables = {
      EXAMPLE_SESSION_VAR = "value";
    };
  };
  
  # Shell aliases
  examples.shellAliases = {
    environment.shellAliases = {
      example = "example-command --config ${config.example.configFile}";
      ex = "example";
    };
  };

  # ============================================================================
  # PACKAGE OVERLAY PATTERNS
  # ============================================================================
  
  # Custom package with overlay
  examples.customPackage = {
    nixpkgs.overlays = [
      (_final: prev: {
        example-custom = prev.example-package.overrideAttrs (oldAttrs: {
          version = "custom";
          buildInputs = oldAttrs.buildInputs ++ [ prev.extra-dependency ];
        });
      })
    ];
  };

  # ============================================================================
  # MONITORING AND LOGGING PATTERNS
  # ============================================================================
  
  # Log rotation
  examples.logRotation = {
    services.logrotate.settings.example = {
      files = [ "/var/log/example/*.log" ];
      frequency = "daily";
      rotate = 30;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "644 example-user example-group";
      postrotate = ''
        systemctl reload example-service
      '';
    };
  };
  
  # Prometheus exporter pattern
  examples.prometheusExporter = {
    services.prometheus.exporters.example = {
      enable = true;
      port = 9100;
      listenAddress = "127.0.0.1";
      extraFlags = [ "--example.flag=value" ];
    };
  };

  # ============================================================================
  # DEVELOPMENT HELPERS
  # ============================================================================
  
  # Debug assertions for development
  examples.debugAssertions = [
    {
      assertion = config.example.debug -> config.example.enable;
      message = "Debug mode requires the main feature to be enabled";
    }
  ];
  
  # Development warnings
  examples.devWarnings = [
    (mkIf config.example.debug ''
      Example is running in debug mode. This should not be used in production.
    '')
  ];
}