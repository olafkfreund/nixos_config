# Central Module Registry
# This file coordinates all module imports and prevents conflicts
{ config
, lib
, ...
}:
with lib; {
  imports = [
    # Core system modules (essential functionality)
    ./core.nix # Core system configuration
    ./performance.nix # Performance optimization
    ./server.nix # Server-specific configurations

    # Feature modules (conditional functionality)
    ./development.nix # Development tools and environments
    ./desktop.nix # Desktop environment configurations
    ./virtualization.nix # Virtualization and containerization
    ./cloud.nix # Cloud provider tools
    ./programs.nix # Application programs
    ./email.nix # Email client configuration
    ./windows/winboat.nix # Windows app integration

    # Service modules (specific services)
    ./services/default.nix # Service configurations
    ./ai/default.nix # AI provider integrations
    ./containers/default.nix # Container runtimes
    ./security/default.nix # Security hardening

    # Infrastructure modules
    ./common/default.nix # Common utilities and features
    ./common/ai-defaults.nix # AI provider defaults
    ./secrets/api-keys.nix # Secret management
    ./microvms/default.nix # MicroVM configurations
  ];

  # Module validation and conflict detection
  config = {
    assertions = [
      {
        assertion = !(config.features.development.enable && config.features.minimal.enable or false);
        message = "Cannot enable both development and minimal features simultaneously";
      }
      {
        assertion =
          !(config.services.docker.enable or false && config.services.podman.enable or false)
          || (config.virtualization.containers.backend or null != null);
        message = "Both Docker and Podman are enabled. Please specify a primary backend in virtualization.containers.backend";
      }
    ];

    warnings =
      optional (config.nixpkgs.config.allowUnfree or false && config.nixpkgs.config.allowInsecure or false)
        "Both allowUnfree and allowInsecure are globally enabled. Consider using targeted package permissions instead."
      ++ optional (builtins.length (attrNames (filterAttrs (_n: v: v.enable or false && hasAttr "mkForce" (attrNames v)) config.services)) > 0)
        "Some services are using mkForce. This may indicate configuration conflicts.";
  };

  # Global module options that can be used by all modules
  options = {
    infrastructure = {
      hostType = mkOption {
        type = types.enum [ "workstation" "server" "laptop" "minimal" ];
        default = "workstation";
        description = lib.mdDoc ''
          Type of host configuration. This affects which modules are loaded
          and how they're configured.
        '';
      };

      hostClass = mkOption {
        type = types.enum [ "development" "production" "testing" ];
        default = "development";
        description = lib.mdDoc ''
          Host class affects security, performance, and feature settings.
        '';
      };
    };

    features = {
      minimal = mkEnableOption "minimal feature set";

      validation = {
        enable = mkEnableOption "strict configuration validation" // { default = true; };
        warningsAsErrors = mkEnableOption "treat warnings as errors";
      };
    };
  };
}
