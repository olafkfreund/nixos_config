{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.ai.providers.gemini;
in
{
  options.ai.providers.gemini = {
    enabled = mkOption {
      type = types.bool;
      default = false;
      description = "Internal option set by main providers module";
    };
  };

  config = mkIf cfg.enabled {
    # Enhanced Google Gemini tools
    environment.systemPackages = with pkgs; [
      # Custom Gemini CLI from the existing configuration
      gemini-cli

      # Tools that support Gemini API
      # aichat REMOVED due to extremely slow pyrate-limiter build dependency (2+ hours)
    ];

    # Gemini-specific environment setup
    environment.sessionVariables = {
      GEMINI_API_KEY_FILE = "/run/secrets/api-gemini";
      GEMINI_MODEL_DEFAULT = config.ai.providers.gemini.defaultModel;
    };

    # Shell integration for Google Gemini
    programs.zsh.interactiveShellInit = mkAfter ''
      # Google Gemini provider functions
      gemini-chat() {
        local model="''${1:-${config.ai.providers.gemini.defaultModel}}"
        local prompt="''${2:-}"
        if [[ -f "/run/secrets/api-gemini" ]]; then
          export GEMINI_API_KEY="$(cat /run/secrets/api-gemini)"
          if command -v gemini-cli >/dev/null 2>&1; then
            if [[ -n "$prompt" ]]; then
              gemini-cli --model "$model" "$prompt"
            else
              gemini-cli --model "$model"
            fi
          elif command -v aichat >/dev/null 2>&1; then
            if [[ -n "$prompt" ]]; then
              aichat --model "gemini:$model" "$prompt"
            else
              aichat --model "gemini:$model"
            fi
          else
            echo "No Gemini CLI tools available"
          fi
        else
          echo "Gemini API key not found"
        fi
      }

      gemini-code() {
        local model="''${1:-${config.ai.providers.gemini.defaultModel}}"
        local prompt="''${2:-}"
        if [[ -f "/run/secrets/api-gemini" ]]; then
          export GEMINI_API_KEY="$(cat /run/secrets/api-gemini)"
          if command -v aichat >/dev/null 2>&1; then
            if [[ -n "$prompt" ]]; then
              aichat --model "gemini:$model" --role code "$prompt"
            else
              aichat --model "gemini:$model" --role code
            fi
          else
            echo "aichat not available for Gemini integration"
          fi
        else
          echo "Gemini API key not found"
        fi
      }

      # Gemini-specific utilities
      gemini-vision() {
        local image="$1"
        local prompt="''${2:-Describe this image}"
        local model="''${3:-gemini-1.5-pro}"
        if [[ -f "$image" && -f "/run/secrets/api-gemini" ]]; then
          export GEMINI_API_KEY="$(cat /run/secrets/api-gemini)"
          echo "Analyzing image: $image with Gemini Vision"
          if command -v gemini-cli >/dev/null 2>&1; then
            gemini-cli --model "$model" --image "$image" "$prompt"
          else
            echo "Gemini CLI not available for vision tasks"
          fi
        else
          echo "Image file not found or Gemini API key missing"
        fi
      }

      gemini-translate() {
        local text="$1"
        local target_lang="''${2:-English}"
        local model="''${3:-${config.ai.providers.gemini.defaultModel}}"
        if [[ -n "$text" && -f "/run/secrets/api-gemini" ]]; then
          export GEMINI_API_KEY="$(cat /run/secrets/api-gemini)"
          gemini-chat "$model" "Translate the following text to $target_lang: $text"
        else
          echo "Text or Gemini API key missing"
        fi
      }

      # Aliases for quick access
      alias ai-gemini='gemini-chat'
      alias code-gemini='gemini-code'
      alias vision-gemini='gemini-vision'
      alias translate-gemini='gemini-translate'
    '';
  };
}
