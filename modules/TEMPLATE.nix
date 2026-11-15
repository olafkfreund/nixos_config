# NixOS Module Template
# Copy this template and customize for new modules
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption mkPackageOption types optionals;
  cfg = config.features.module-name;
in
{
  options.features.module-name = {
    enable = mkEnableOption "module functionality";

    package = mkPackageOption pkgs "package-name" {
      description = "Package to use for this module";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Configuration settings for the module";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra configuration to append to the generated config file";
    };
  };

  config = mkIf cfg.enable {
    # Main service configuration
    services.example-service = {
      enable = true;
      inherit (cfg) package;
    };

    # System packages if needed
    environment.systemPackages = [ cfg.package ];

    # Assertions for validation
    assertions = [
      {
        assertion = cfg.settings != { };
        message = "Module requires at least one configuration setting";
      }
    ];

    # Warnings for deprecated options
    warnings = optionals (cfg.extraConfig != "") [
      "extraConfig option is deprecated, use settings instead"
    ];
  };
}
