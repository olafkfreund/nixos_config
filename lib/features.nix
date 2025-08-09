# Enhanced feature system with dependency resolution and validation
{ lib
, config
, ...
}:
let
  inherit (lib) mkOption types attrNames filter flatten;

  # Feature registry with metadata
  featureRegistry = {
    development = {
      dependencies = [ "networking" ];
      conflicts = [ ];
      description = "Development environment setup";
      modules = [
        "development/git"
        "development/editors"
        "development/languages"
      ];
    };

    gaming = {
      dependencies = [ "graphics" ];
      conflicts = [ "server-minimal" ];
      description = "Gaming setup with Steam and related tools";
      modules = [
        "games/steam"
        "games/lutris"
      ];
    };

    virtualization = {
      dependencies = [ "networking" ];
      conflicts = [ "minimal" ];
      description = "Virtualization with Docker, QEMU, etc.";
      modules = [
        "virtualization/docker"
        "virtualization/libvirt"
      ];
    };

    security = {
      dependencies = [ ];
      conflicts = [ ];
      description = "Security tools and hardening";
      modules = [
        "security/hardening"
        "security/tools"
      ];
    };

    desktop = {
      dependencies = [ "graphics" ];
      conflicts = [ "server-minimal" ];
      description = "Desktop environment and applications";
      modules = [
        "desktop/hyprland"
        "desktop/applications"
      ];
    };
  };

  # Validate feature dependencies
  validateFeatures = enabledFeatures:
    let
      enabledNames = attrNames enabledFeatures;

      # Check dependencies
      missingDeps = flatten (map
        (
          feature:
          let
            deps = featureRegistry.${feature}.dependencies or [ ];
            missing = filter (dep: !(enabledFeatures.${dep} or false)) deps;
          in
          map (dep: "${feature} requires ${dep}") missing
        )
        enabledNames);

      # Check conflicts
      conflicts = flatten (map
        (
          feature:
          let
            conflictList = featureRegistry.${feature}.conflicts or [ ];
            activeConflicts = filter (conflict: enabledFeatures.${conflict} or false) conflictList;
          in
          map (conflict: "${feature} conflicts with ${conflict}") activeConflicts
        )
        enabledNames);
    in
    {
      inherit missingDeps conflicts;
      isValid = (missingDeps == [ ]) && (conflicts == [ ]);
    };

  # Feature profiles for common configurations
  profiles = {
    workstation = {
      development.enable = true;
      desktop.enable = true;
      virtualization.enable = true;
      security.enable = true;
    };

    gaming = {
      desktop.enable = true;
      gaming.enable = true;
      security.enable = true;
    };

    server = {
      virtualization.enable = true;
      security.enable = true;
      networking.enable = true;
    };

    minimal = {
      security.enable = true;
    };
  };
in
{
  options = {
    featureProfiles = mkOption {
      type = types.attrsOf types.bool;
      default = { };
      description = "Enable predefined feature profiles";
    };

    features = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable this feature set";
          };
        };
      });
      default = { };
      description = "Feature configuration";
    };
  };

  config =
    let
      # Merge profile features with explicit features
      profileFeatures = lib.foldl' lib.recursiveUpdate { } (
        map (profile: profiles.${profile})
          (filter (profile: config.featureProfiles.${profile} or false) (attrNames profiles))
      );

      allFeatures = lib.recursiveUpdate profileFeatures config.features;
      validation = validateFeatures allFeatures;
    in
    {
      # Feature validation assertions
      assertions = [
        {
          assertion = validation.isValid;
          message = ''
            Feature validation failed:
            Missing dependencies: ${lib.concatStringsSep ", " validation.missingDeps}
            Conflicts: ${lib.concatStringsSep ", " validation.conflicts}
          '';
        }
      ];

      # Export validated features for use by other modules
      _module.args.enabledFeatures = allFeatures;
      _module.args.featureValidation = validation;
    };
}
