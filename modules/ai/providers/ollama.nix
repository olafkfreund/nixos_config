{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.ai.providers.ollama;
in
{
  options.ai.providers.ollama = {
    enabled = mkOption {
      type = types.bool;
      default = false;
      description = "Internal option set by main providers module";
    };
  };

  config = mkIf cfg.enabled {
    # Enhanced Ollama local AI tools
    environment.systemPackages = with pkgs; [
      # Core Ollama tools
      ollama

      # Tools that work well with Ollama
      aichat # Supports Ollama models
    ];

    # Ollama-specific environment setup
    environment.sessionVariables = {
      OLLAMA_HOST = config.ai.providers.ollama.host;
      OLLAMA_MODEL_DEFAULT = config.ai.providers.ollama.defaultModel;
    };

    # Shell integration for Ollama
    programs.zsh.interactiveShellInit = mkAfter ''
      # Ollama provider functions
      ollama-chat() {
        local model="''${1:-${config.ai.providers.ollama.defaultModel}}"
        local prompt="''${2:-}"
        if command -v ollama >/dev/null 2>&1; then
          # Check if Ollama service is running
          if ollama list >/dev/null 2>&1; then
            if [[ -n "$prompt" ]]; then
              ollama run "$model" "$prompt"
            else
              ollama run "$model"
            fi
          else
            echo "Ollama service not running. Start with: systemctl start ollama"
          fi
        else
          echo "Ollama not available"
        fi
      }

      ollama-code() {
        local model="''${1:-${config.ai.providers.ollama.defaultModel}}"
        local prompt="''${2:-}"
        if command -v aichat >/dev/null 2>&1; then
          if [[ -n "$prompt" ]]; then
            aichat --model "ollama:$model" --role code "$prompt"
          else
            aichat --model "ollama:$model" --role code
          fi
        elif command -v ollama >/dev/null 2>&1; then
          local code_prompt="You are a coding assistant. Provide clean, working code with explanations. $prompt"
          ollama run "$model" "$code_prompt"
        else
          echo "No suitable Ollama client available"
        fi
      }

      # Ollama management utilities
      ollama-models() {
        echo "Available Ollama models:"
        if command -v ollama >/dev/null 2>&1; then
          ollama list
        else
          echo "Ollama not available"
        fi
      }

      ollama-pull() {
        local model="$1"
        if [[ -z "$model" ]]; then
          echo "Usage: ollama-pull <model_name>"
          echo "Example: ollama-pull mistral"
          return 1
        fi
        if command -v ollama >/dev/null 2>&1; then
          ollama pull "$model"
        else
          echo "Ollama not available"
        fi
      }

      ollama-status() {
        echo "Ollama Service Status:"
        if command -v systemctl >/dev/null 2>&1; then
          systemctl status ollama --no-pager -l
        fi
        echo ""
        echo "Available Models:"
        ollama-models
      }

      ollama-embed() {
        local text="$1"
        local model="''${2:-nomic-embed-text}"
        if [[ -n "$text" ]]; then
          curl -s "http://${config.ai.providers.ollama.host}/api/embeddings" \
            -d "{\"model\": \"$model\", \"prompt\": \"$text\"}" | jq '.embedding'
        else
          echo "Usage: ollama-embed <text> [model]"
        fi
      }

      # Aliases for quick access
      alias ai-ollama='ollama-chat'
      alias code-ollama='ollama-code'
      alias models-ollama='ollama-models'
      alias pull-ollama='ollama-pull'
      alias status-ollama='ollama-status'
    '';

    # Ensure Ollama service integration
    systemd.services.ollama = mkIf config.services.ollama.enable {
      environment = {
        OLLAMA_HOST = "0.0.0.0:11434";
        OLLAMA_ORIGINS = "*";
      };
    };
  };
}
