# High-Performance Module Registry
# Reduces 215 modules to ~12 consolidated modules
{ config, lib, ... }:
with lib; {
  imports = [
    # Core consolidated modules (replaces 40+ modules)
    ./core.nix
    ./desktop.nix
    ./development.nix

    # Feature-based lazy loading
    ./lazy-imports.nix
  ]
  # Conditional imports - only load if explicitly requested
  ++ optionals (config.features.ai.enable or false) [ ./ai.nix ]
  ++ optionals (config.features.virtualization.enable or false) [ ./virtualization.nix ];

  # Fast validation - reduced assertion count
  config.assertions = [
    {
      assertion =
        let
          conflicts = with config.features; [
            (development.enable && minimal.enable)
            (ai.enable && minimal.enable)
          ];
        in
          !any (x: x) conflicts;
      message = "Conflicting feature combinations detected";
    }
  ];

  # Global performance options
  options.performance = {
    evaluation = {
      enableLazyLoading = mkEnableOption "lazy module loading" // { default = true; };
      enableFastValidation = mkEnableOption "fast validation" // { default = true; };
    };
  };
}
