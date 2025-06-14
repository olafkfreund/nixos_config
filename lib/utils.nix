{lib}: let
  inherit (lib) mkOption types;
in {
  # Utility functions for configuration generation
  mkCustomOptions = {
    # Helper to create enable options with descriptions
    mkEnableOpt = description: lib.mkEnableOption description;

    # Helper to create string options with defaults
    mkStrOpt = default: description:
      mkOption {
        type = types.str;
        inherit default description;
      };

    # Helper to create list options
    mkListOpt = elemType: default: description:
      mkOption {
        type = types.listOf elemType;
        inherit default description;
      };

    # Helper to create enum options
    mkEnumOpt = values: default: description:
      mkOption {
        type = types.enum values;
        inherit default description;
      };
  };

  # Configuration validation helpers
  validators = {
    # Validate that required users exist
    validateUsers = users: config:
      lib.all (user: config.users.users ? ${user}) users;

    # Validate hardware configuration
    validateHardware = hardwareConfig:
      hardwareConfig ? cpu && hardwareConfig ? gpu;

    # Validate service dependencies
    validateServiceDeps = services: config:
      lib.all (service: config.systemd.services ? ${service}) services;
  };

  # Helper functions for module imports
  moduleHelpers = {
    # Conditionally import modules based on host type
    importForHostType = hostType: modules:
      if modules ? ${hostType}
      then modules.${hostType}
      else [];

    # Import modules with error handling
    safeImport = path:
      if builtins.pathExists path
      then [path]
      else [];
  };

  # Debug helpers
  debug = {
    # Print configuration for debugging
    printConfig = config: lib.trivial.warn "Config: ${lib.generators.toPretty {} config}" config;

    # Validate option types
    validateTypes = options: config:
      lib.mapAttrs (
        name: opt:
          if config ? ${name}
          then opt.type.check config.${name}
          else opt ? default
      )
      options;
  };
}
