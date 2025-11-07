{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.ai.providers.anthropic;
in
{
  options.ai.providers.anthropic = {
    enabled = mkOption {
      type = types.bool;
      default = false;
      description = "Internal option set by main providers module";
    };
  };

  config = mkIf cfg.enabled {
    # Enhanced Anthropic/Claude tools
    environment.systemPackages = with pkgs; [
      # Claude Desktop app if available
      # claude-desktop # Add when available in nixpkgs

      # CLI tools that support Claude API
      # aichat REMOVED due to extremely slow pyrate-limiter build dependency (2+ hours)
    ];

    # Anthropic-specific environment setup
    environment.sessionVariables = {
      ANTHROPIC_API_KEY_FILE = "/run/secrets/api-anthropic";
      CLAUDE_MODEL_DEFAULT = config.ai.providers.anthropic.defaultModel;
    };

    # Shell integration for Anthropic Claude
    programs.zsh.interactiveShellInit = mkAfter ''
      # Anthropic Claude provider functions
      claude-chat() {
        local model="''${1:-${config.ai.providers.anthropic.defaultModel}}"
        local prompt="''${2:-}"
        if [[ -f "/run/secrets/api-anthropic" ]]; then
          export ANTHROPIC_API_KEY="$(cat /run/secrets/api-anthropic)"
          if command -v aichat >/dev/null 2>&1; then
            if [[ -n "$prompt" ]]; then
              aichat --model "claude:$model" "$prompt"
            else
              aichat --model "claude:$model"
            fi
          else
            echo "aichat not available for Claude integration"
          fi
        else
          echo "Anthropic API key not found"
        fi
      }

      claude-code() {
        local model="''${1:-${config.ai.providers.anthropic.defaultModel}}"
        local prompt="''${2:-}"
        if [[ -f "/run/secrets/api-anthropic" ]]; then
          export ANTHROPIC_API_KEY="$(cat /run/secrets/api-anthropic)"
          if command -v aichat >/dev/null 2>&1; then
            if [[ -n "$prompt" ]]; then
              aichat --model "claude:$model" --role code "$prompt"
            else
              aichat --model "claude:$model" --role code
            fi
          else
            echo "aichat not available for Claude integration"
          fi
        else
          echo "Anthropic API key not found"
        fi
      }

      # Claude-specific utilities
      claude-analyze() {
        local file="$1"
        local model="''${2:-${config.ai.providers.anthropic.defaultModel}}"
        if [[ -f "$file" && -f "/run/secrets/api-anthropic" ]]; then
          export ANTHROPIC_API_KEY="$(cat /run/secrets/api-anthropic)"
          echo "Analyzing file: $file with Claude"
          aichat --model "claude:$model" "Please analyze this file:" < "$file"
        else
          echo "File not found or Anthropic API key missing"
        fi
      }

      # Aliases for quick access
      alias ai-claude='claude-chat'
      alias code-claude='claude-code'
      alias analyze-claude='claude-analyze'
    '';

    # Create wrapper script for Claude Desktop if needed
    environment.etc."claude-desktop-wrapper.sh" = {
      text = ''
        #!/bin/bash
        # Claude Desktop wrapper with API key loading
        if [[ -f "/run/secrets/api-anthropic" ]]; then
          export ANTHROPIC_API_KEY="$(cat /run/secrets/api-anthropic)"
        fi
        # Launch Claude Desktop if available
        if command -v claude-desktop >/dev/null 2>&1; then
          claude-desktop "$@"
        else
          echo "Claude Desktop not available. Using web interface..."
          xdg-open "https://claude.ai"
        fi
      '';
      mode = "0755";
    };
  };
}
