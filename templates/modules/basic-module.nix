# Basic NixOS Module Template
#
# This template provides the standard structure for a NixOS module
# following the established patterns in this codebase.
#
# Usage:
# 1. Copy this template to your desired location in modules/
# 2. Replace PLACEHOLDER values with your module specifics
# 3. Add your module to the appropriate imports in modules/default.nix
# 4. Enable in host configuration with: features.CATEGORY.MODULE = true;
{ config
, lib
, pkgs
, ...
}:
with lib; let
  # Configuration reference - adjust path to match your module location
  cfg = config.modules.CATEGORY.MODULE_NAME;
in
{
  # Module options definition
  options.modules.CATEGORY.MODULE_NAME = {
    enable = mkEnableOption "DESCRIPTION_OF_MODULE";

    # Example string option
    exampleOption = mkOption {
      type = types.str;
      default = "default-value";
      description = "Example string option description";
      example = "example-value";
    };

    # Example boolean option
    enableFeature = mkOption {
      type = types.bool;
      default = false;
      description = "Enable optional feature";
    };

    # Example list option
    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages to install";
      example = literalExpression "[ pkgs.example-package ]";
    };

    # Example attribute set option
    settings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Configuration settings";
      example = literalExpression ''
        {
          key1 = "value1";
          key2 = "value2";
        }
      '';
    };
  };

  # Module configuration - only applied when enabled
  config = mkIf cfg.enable {
    # System packages
    environment.systemPackages = with pkgs;
      [
        # Add your packages here
        # example-package
      ]
      ++ cfg.packages;

    # Example service configuration
    # systemd.services.MODULE_NAME = {
    #   description = "SERVICE_DESCRIPTION";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "simple";
    #     User = "USER_NAME";
    #     Group = "GROUP_NAME";
    #     ExecStart = "${pkgs.example-package}/bin/example-command";
    #     Restart = "always";
    #     RestartSec = "10s";
    #   };
    # };

    # Example environment variables
    # environment.variables = cfg.settings;

    # Example conditional configuration
    # programs.example = mkIf cfg.enableFeature {
    #   enable = true;
    #   settings = cfg.settings;
    # };

    # Validation assertions
    assertions = [
      {
        assertion = cfg.exampleOption != "";
        message = "MODULE_NAME exampleOption cannot be empty";
      }
    ];

    # Helpful warnings
    warnings = [
      (mkIf (cfg.enableFeature && cfg.packages == [ ]) ''
        MODULE_NAME: enableFeature is true but no packages specified.
        Consider adding packages to cfg.packages.
      '')
    ];
  };
}
