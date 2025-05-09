{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.editor.windsurf;
in {
  options.editor.windsurf = {
    enable = mkEnableOption {
      default = true;
      description = "windsurf";
    };
    
    extraPackages = mkOption {
      type = with types; listOf package;
      default = [];
      description = "Additional packages to add to the Windsurf environment";
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a custom Windsurf config file";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Windsurf settings as a Nix attribute set";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      alejandra 
      deadnix 
      statix
    ] ++ cfg.extraPackages;

    programs.windsurf = {
      enable = true;
      package = pkgs.windsurf;
      
      # Apply user settings
      settings = cfg.settings;
    };

    # If the user specified a custom config file, link it
    xdg.configFile = mkIf (cfg.configFile != null) {
      "windsurf/config.toml".source = cfg.configFile;
    };
  };
}
