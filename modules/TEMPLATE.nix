# NixOS Module Template
# This template provides a standardized structure for all modules in this configuration
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.modules.category.moduleName;
in {
  # Module metadata (optional but recommended for complex modules)
  meta = {
    description = "Brief description of what this module provides";
    maintainers = [ "olafkfreund" ];
    # documentation = [ "./README.md" ];
  };

  # Options definition with comprehensive documentation
  options.modules.category.moduleName = {
    # Primary enable option - every module should have this
    enable = mkEnableOption "Enable [module functionality description]";

    # Example package selection option
    packages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = ''
        List of additional packages to install with this module.
        These extend the default package set.
      '';
      example = literalExpression ''
        with pkgs; [
          package1
          package2
        ]
      '';
    };

    # Example configuration option
    settings = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = ''
        Configuration settings for the module.
        These will be merged with default settings.
      '';
      example = literalExpression ''
        {
          option1 = "value1";
          option2 = 42;
          section = {
            nestedOption = true;
          };
        }
      '';
    };

    # Example user-specific option
    users = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        List of users who should have access to this module's features.
        Empty list means all users have access.
      '';
      example = [ "alice" "bob" ];
    };
  };

  # Configuration implementation
  config = mkIf cfg.enable {
    # Package installation
    environment.systemPackages = with pkgs; [
      # Default packages for this module
      defaultPackage1
      defaultPackage2
    ] ++ cfg.packages;

    # Service configuration (if applicable)
    systemd.services.module-service = {
      description = "Service description";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        # Additional service configuration
      };
    };

    # User configuration (if applicable)
    users.users = genAttrs cfg.users (_user: {
      extraGroups = [ "module-group" ];
    });

    # Environment variables (if applicable)
    environment.sessionVariables = {
      MODULE_CONFIG = toString (pkgs.writeText "module-config" 
        (generators.toINI {} cfg.settings));
    };

    # Assertions for validation
    assertions = [
      {
        assertion = cfg.users == [] || all (user: hasAttr user config.users.users) cfg.users;
        message = "All users specified in modules.category.moduleName.users must exist";
      }
    ];

    # Warnings for deprecated options
    warnings = optional (cfg.settings ? deprecatedOption) ''
      modules.category.moduleName.settings.deprecatedOption is deprecated.
      Use modules.category.moduleName.settings.newOption instead.
    '';
  };
}