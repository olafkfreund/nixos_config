{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.modules.ai.gemini-cli;
  geminiCliPkg = pkgs.gemini-cli;
in
{
  options.modules.ai.gemini-cli = {
    enable = mkEnableOption "Google Gemini CLI - AI workflow tool";

    package = mkOption {
      type = types.package;
      default = geminiCliPkg;
      description = "The gemini-cli package to use";
    };

    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables to set for gemini-cli";
      example = {
        GEMINI_API_KEY = "your-api-key";
        GEMINI_MODEL = "gemini-2.5-pro";
      };
    };

    enableShellIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable shell integration for gemini-cli";
    };
  };

  config = mkIf cfg.enable {
    environment = {
      # Add the package to system packages
      systemPackages = [ cfg.package ];

      # Set environment variables if provided
      variables = cfg.environmentVariables;

      # Optional shell integration
      shellAliases = mkIf cfg.enableShellIntegration {
        gemini = "gemini";
        ai = mkDefault "gemini"; # Convenient alias with default priority
      };

      # Create a desktop entry for GUI environments
      etc."applications/gemini-cli.desktop" = mkIf cfg.enableShellIntegration {
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
  };
}
