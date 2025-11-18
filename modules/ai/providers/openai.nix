{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.ai.providers.openai;
in
{
  options.ai.providers.openai = {
    enabled = mkOption {
      type = types.bool;
      default = false;
      description = "Internal option set by main providers module";
    };
  };

  config = mkIf cfg.enabled {
    # Enhanced OpenAI tools and configuration
    environment.systemPackages = with pkgs; [
      # Core OpenAI tools
      openai-whisper
      # shell-gpt REMOVED due to dependency conflict with openai>=2.0.0
      # Enhanced CLI tools
      tgpt
      # aichat REMOVED due to extremely slow pyrate-limiter build dependency (2+ hours)
    ];

    # OpenAI-specific environment setup
    environment.sessionVariables = {
      OPENAI_API_KEY_FILE = "/run/secrets/api-openai";
      OPENAI_MODEL_DEFAULT = config.ai.providers.openai.defaultModel;
    };

    # Shell integration for OpenAI
    programs.zsh.interactiveShellInit = mkAfter ''
      # OpenAI provider functions using tgpt (replacement for shell-gpt)
      openai-chat() {
        local model="''${1:-${config.ai.providers.openai.defaultModel}}"
        local prompt="''${2:-}"
        if [[ -f "/run/secrets/api-openai" ]]; then
          export OPENAI_API_KEY="$(cat /run/secrets/api-openai)"
          if [[ -n "$prompt" ]]; then
            tgpt --provider openai --model "$model" "$prompt"
          else
            echo "Usage: openai-chat [model] <prompt>"
          fi
        else
          echo "OpenAI API key not found"
        fi
      }

      openai-code() {
        local model="''${1:-${config.ai.providers.openai.defaultModel}}"
        local prompt="''${2:-}"
        if [[ -f "/run/secrets/api-openai" ]]; then
          export OPENAI_API_KEY="$(cat /run/secrets/api-openai)"
          if [[ -n "$prompt" ]]; then
            tgpt --provider openai --model "$model" --code "$prompt"
          else
            echo "Usage: openai-code [model] <prompt>"
          fi
        else
          echo "OpenAI API key not found"
        fi
      }

      # Aliases for quick access
      alias ai-openai='openai-chat'
      alias code-openai='openai-code'
    '';
  };
}
