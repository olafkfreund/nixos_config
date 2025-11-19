{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.antigravity;
in
{
  options.programs.antigravity = {
    enable = mkEnableOption "Google Antigravity IDE";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The Google Antigravity package to use.";
    };

    apiKeys = {
      gemini = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Google Gemini API key for AI model access.
          Can be obtained from https://makersuite.google.com/app/apikey
        '';
      };

      anthropic = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Anthropic Claude API key for AI model access.
          Can be obtained from https://console.anthropic.com/
        '';
      };

      openai = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          OpenAI GPT API key for AI model access.
          Can be obtained from https://platform.openai.com/api-keys
        '';
      };
    };

    desktopEntry = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create a desktop entry for Google Antigravity.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Set API keys as environment variables and enable Wayland support
    home.sessionVariables = mkMerge [
      (mkIf (cfg.apiKeys.gemini != null) {
        GOOGLE_API_KEY = cfg.apiKeys.gemini;
        GEMINI_API_KEY = cfg.apiKeys.gemini;
      })
      (mkIf (cfg.apiKeys.anthropic != null) {
        ANTHROPIC_API_KEY = cfg.apiKeys.anthropic;
      })
      (mkIf (cfg.apiKeys.openai != null) {
        OPENAI_API_KEY = cfg.apiKeys.openai;
      })
      # Wayland support for Electron
      { NIXOS_OZONE_WL = "1"; }
    ];
  };
}
