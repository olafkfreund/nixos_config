{ config
, lib
, ...
}:
with lib; let
  cfg = config.ai.providers;
in
{
  imports = [
    ./openai.nix
    ./anthropic.nix
    ./gemini.nix
    ./unified-client.nix
  ];

  options.ai.providers = {
    enable = mkEnableOption "Enhanced AI provider support with unified interface";

    defaultProvider = mkOption {
      type = types.enum [ "openai" "anthropic" "gemini" ];
      default = "anthropic";
      description = "Default AI provider to use";
      example = "openai";
    };

    enableFallback = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic fallback between providers";
    };

    costOptimization = mkOption {
      type = types.bool;
      default = false;
      description = "Enable cost-based provider selection";
    };

    timeout = mkOption {
      type = types.int;
      default = 30;
      description = "Request timeout in seconds";
    };

    maxRetries = mkOption {
      type = types.int;
      default = 3;
      description = "Maximum number of retries per provider";
    };

    openai = {
      enable = mkEnableOption "OpenAI provider support";
      priority = mkOption {
        type = types.int;
        default = 1;
        description = "Provider priority (1 = highest)";
      };
      models = mkOption {
        type = types.listOf types.str;
        default = [ "gpt-4o" "gpt-4o-mini" "gpt-3.5-turbo" ];
        description = "Available OpenAI models";
      };
      defaultModel = mkOption {
        type = types.str;
        default = "gpt-4o-mini";
        description = "Default OpenAI model";
      };
    };

    anthropic = {
      enable = mkEnableOption "Anthropic/Claude provider support";
      priority = mkOption {
        type = types.int;
        default = 2;
        description = "Provider priority (1 = highest)";
      };
      models = mkOption {
        type = types.listOf types.str;
        default = [ "claude-sonnet-4-6" "claude-haiku-4-5-20251001" "claude-opus-4-6" ];
        description = "Available Anthropic models";
      };
      defaultModel = mkOption {
        type = types.str;
        default = "claude-sonnet-4-6";
        description = "Default Anthropic model";
      };
    };

    gemini = {
      enable = mkEnableOption "Google Gemini provider support";
      priority = mkOption {
        type = types.int;
        default = 3;
        description = "Provider priority (1 = highest)";
      };
      models = mkOption {
        type = types.listOf types.str;
        default = [ "gemini-2.5-pro" "gemini-2.5-flash" "gemini-2.0-flash" ];
        description = "Available Gemini models";
      };
      defaultModel = mkOption {
        type = types.str;
        default = "gemini-2.5-flash";
        description = "Default Gemini model";
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable individual provider modules based on configuration
    ai.providers = {
      openai.enabled = cfg.openai.enable;
      anthropic.enabled = cfg.anthropic.enable;
      gemini.enabled = cfg.gemini.enable;
    };

    # Create provider configuration file
    environment.etc."ai-providers.json".text = builtins.toJSON {
      inherit (cfg) defaultProvider;
      inherit (cfg) enableFallback;
      inherit (cfg) costOptimization;
      inherit (cfg) timeout;
      inherit (cfg) maxRetries;

      providers = lib.filterAttrs (_name: value: value != null) {
        openai =
          if cfg.openai.enable
          then {
            enabled = true;
            inherit (cfg.openai) priority;
            inherit (cfg.openai) models;
            inherit (cfg.openai) defaultModel;
            apiKeyFile = "/run/agenix/api-openai";
            baseUrl = "https://api.openai.com/v1";
            requiresApiKey = true;
          }
          else null;

        anthropic =
          if cfg.anthropic.enable
          then {
            enabled = true;
            inherit (cfg.anthropic) priority;
            inherit (cfg.anthropic) models;
            inherit (cfg.anthropic) defaultModel;
            apiKeyFile = "/run/agenix/api-anthropic";
            baseUrl = "https://api.anthropic.com";
            requiresApiKey = true;
          }
          else null;

        gemini =
          if cfg.gemini.enable
          then {
            enabled = true;
            inherit (cfg.gemini) priority;
            inherit (cfg.gemini) models;
            inherit (cfg.gemini) defaultModel;
            apiKeyFile = "/run/agenix/api-gemini";
            baseUrl = "https://generativelanguage.googleapis.com/v1beta";
            requiresApiKey = true;
          }
          else null;
      };
    };

    # Add environment variables for easier access
    environment.sessionVariables = {
      AI_PROVIDERS_CONFIG = "/etc/ai-providers.json";
      AI_DEFAULT_PROVIDER = cfg.defaultProvider;
    };
  };
}
