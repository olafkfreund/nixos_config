{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.gemini-cli;
  # Import our custom gemini-cli package
  geminiCliPkg = pkgs.callPackage ../../pkgs/gemini-cli {};
in {
  options.programs.gemini-cli = {
    enable = lib.mkEnableOption "Google Gemini CLI - AI workflow tool";

    package = lib.mkOption {
      type = lib.types.package;
      default = geminiCliPkg;
      description = "The gemini-cli package to use";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Environment variables to set for gemini-cli";
      example = {
        GEMINI_API_KEY = "your-api-key";
        GEMINI_MODEL = "gemini-2.5-pro";
      };
    };

    enableShellIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable shell integration for gemini-cli";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add the package to system packages
    environment.systemPackages = [cfg.package];

    # Set environment variables if provided
    environment.variables = cfg.environmentVariables;

    # Optional shell integration
    environment.shellAliases = lib.mkIf cfg.enableShellIntegration {
      gemini = "gemini";
      ai = "gemini"; # Convenient alias
    };

    # Create a desktop entry for GUI environments
    environment.etc."applications/gemini-cli.desktop" = lib.mkIf cfg.enableShellIntegration {
      text = ''
        [Desktop Entry]
        Name=Gemini CLI
        Comment=Google Gemini AI Command Line Interface
        Exec=${cfg.package}/bin/gemini
        Icon=terminal
        Type=Application
        Terminal=true
        Categories=Development;Utility;ConsoleOnly;
        Keywords=AI;Gemini;CLI;Google;
      '';
    };
  };
}
