{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.editor.windsurf;

  # Helper function to format TOML manually since generators.toTOML is not available
  settingsToToml = attrs:
    let
      mkValue = v:
        if builtins.isString v then ''"${v}"''
        else if builtins.isBool v then (if v then "true" else "false")
        else if builtins.isInt v || builtins.isFloat v then toString v
        else throw "Unsupported type for TOML conversion";

      lines = lib.mapAttrsToList (k: v: "${k} = ${mkValue v}") attrs;
    in
    builtins.concatStringsSep "\n" lines;
in
{
  options.editor.windsurf = {
    enable = mkEnableOption {
      default = true;
      description = "windsurf";
    };

    extraPackages = mkOption {
      type = with types; listOf package;
      default = [ ];
      description = "Additional packages to add to the Windsurf environment";
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a custom Windsurf config file";
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Windsurf settings as a Nix attribute set";
    };
  };

  config = mkIf cfg.enable {
    # Install windsurf and related packages
    home.packages = with pkgs;
      [
        windsurf
        alejandra
        deadnix
        statix
      ]
      ++ cfg.extraPackages;

    # Configure windsurf - using a more reliable approach for conditional config
    xdg.configFile = mkMerge [
      # Use custom config file if provided
      (mkIf (cfg.configFile != null) {
        "windsurf/config.toml" = {
          source = cfg.configFile;
        };
      })

      # Or generate from settings if no custom file is provided but settings exist
      (mkIf (cfg.configFile == null && cfg.settings != { }) {
        "windsurf/config.toml" = {
          # Generate TOML content manually instead of using generators.toTOML
          text = settingsToToml cfg.settings;
        };
      })
    ];
  };
}
