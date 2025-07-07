{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.ai.providers;
in {
  imports = [
    ./openai.nix
    ./anthropic.nix
    ./gemini.nix
    ./ollama.nix
    ./unified-client.nix
  ];

  options.ai.providers = {
    enable = mkEnableOption "Enhanced AI provider support with unified interface";

    defaultProvider = mkOption {
      type = types.enum ["openai" "anthropic" "gemini" "ollama"];
      default = "openai";
      description = "Default AI provider to use";
      example = "anthropic";
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
        default = ["gpt-4o" "gpt-4o-mini" "gpt-3.5-turbo"];
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
        default = ["claude-3-5-sonnet-20241022" "claude-3-5-haiku-20241022" "claude-3-opus-20240229"];
        description = "Available Anthropic models";
      };
      defaultModel = mkOption {
        type = types.str;
        default = "claude-3-5-sonnet-20241022";
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
        default = ["gemini-1.5-pro" "gemini-1.5-flash" "gemini-2.0-flash-exp"];
        description = "Available Gemini models";
      };
      defaultModel = mkOption {
        type = types.str;
        default = "gemini-1.5-flash";
        description = "Default Gemini model";
      };
    };

    ollama = {
      enable = mkEnableOption "Ollama local provider support";
      priority = mkOption {
        type = types.int;
        default = 4;
        description = "Provider priority (1 = highest)";
      };
      models = mkOption {
        type = types.listOf types.str;
        default = ["mistral-small3.1" "GandalfBaum/llama3.2-claude3.7" "llama3.2"];
        description = "Available Ollama models";
      };
      defaultModel = mkOption {
        type = types.str;
        default = "mistral-small3.1";
        description = "Default Ollama model";
      };
      host = mkOption {
        type = types.str;
        default = "localhost:11434";
        description = "Ollama server host and port";
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable individual provider modules based on configuration
    ai.providers.openai.enabled = cfg.openai.enable;
    ai.providers.anthropic.enabled = cfg.anthropic.enable;
    ai.providers.gemini.enabled = cfg.gemini.enable;
    ai.providers.ollama.enabled = cfg.ollama.enable;

    # Create provider configuration file
    environment.etc."ai-providers.json".text = builtins.toJSON {
      defaultProvider = cfg.defaultProvider;
      enableFallback = cfg.enableFallback;
      costOptimization = cfg.costOptimization;
      timeout = cfg.timeout;
      maxRetries = cfg.maxRetries;
      
      providers = {
        openai = mkIf cfg.openai.enable {
          enabled = true;
          priority = cfg.openai.priority;
          models = cfg.openai.models;
          defaultModel = cfg.openai.defaultModel;
          apiKeyFile = "/run/secrets/api-openai";
          baseUrl = "https://api.openai.com/v1";
        };
        
        anthropic = mkIf cfg.anthropic.enable {
          enabled = true;
          priority = cfg.anthropic.priority;
          models = cfg.anthropic.models;
          defaultModel = cfg.anthropic.defaultModel;
          apiKeyFile = "/run/secrets/api-anthropic";
          baseUrl = "https://api.anthropic.com";
        };
        
        gemini = mkIf cfg.gemini.enable {
          enabled = true;
          priority = cfg.gemini.priority;
          models = cfg.gemini.models;
          defaultModel = cfg.gemini.defaultModel;
          apiKeyFile = "/run/secrets/api-gemini";
          baseUrl = "https://generativelanguage.googleapis.com/v1beta";
        };
        
        ollama = mkIf cfg.ollama.enable {
          enabled = true;
          priority = cfg.ollama.priority;
          models = cfg.ollama.models;
          defaultModel = cfg.ollama.defaultModel;
          baseUrl = "http://${cfg.ollama.host}";
          requiresApiKey = false;
        };
      };
    };

    # Add environment variables for easier access
    environment.sessionVariables = {
      AI_PROVIDERS_CONFIG = "/etc/ai-providers.json";
      AI_DEFAULT_PROVIDER = cfg.defaultProvider;
    };
  };
}