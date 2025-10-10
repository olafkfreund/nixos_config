# Lazy Import System - Only evaluates enabled features
{ config, lib, ... }:
with lib; {
  options.lazy = {
    enabledFeatures = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of features to enable - only these modules are loaded";
    };
  };

  imports =
    let
      # Feature map - much faster than directory scanning
      featureMap = {
        core = ./core.nix;
        desktop = ./desktop.nix;
        development = ./development.nix;
        ai = ./ai.nix;
        virtualization = ./virtualization.nix;
      };

      # Only import enabled features
      enabledModules = map (feature: featureMap.${feature})
        (filter (feature: hasAttr feature featureMap) config.lazy.enabledFeatures);
    in
    enabledModules;
}
