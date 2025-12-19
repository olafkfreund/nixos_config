{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.zshAiCmd;
in
{
  options.programs.zshAiCmd = {
    enable = mkEnableOption "AI-powered shell command suggestions using Anthropic Claude";

    model = mkOption {
      type = types.str;
      default = "claude-haiku-4-5";
      example = "claude-sonnet-4-5";
      description = ''
        Claude model to use for command suggestions.

        Available models (Claude 4.5 - Latest):
        - claude-haiku-4-5 (default, fast and cost-effective)
        - claude-sonnet-4-5 (more powerful, higher quality)
        - claude-opus-4-5 (most capable, highest cost)

        Legacy models (Claude 3.5):
        - claude-3-5-haiku-20241022
        - claude-3-5-sonnet-20241022
        - claude-3-opus-20240229

        See https://docs.anthropic.com/claude/docs/models-overview for details.
      '';
    };

    triggerKey = mkOption {
      type = types.str;
      default = "^G";
      example = "^X";
      description = ''
        Key binding to trigger AI command suggestions.

        Format: zsh key binding syntax (e.g., ^G for Ctrl+G).
        Default: Ctrl+G (doesn't conflict with job control)

        Note: Avoid ^Z (job control) and ^C (interrupt).
      '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable debug logging for troubleshooting.

        WARNING: Debug logs contain full API responses.
        Logs are written to logFile option.
      '';
    };

    logFile = mkOption {
      type = types.str;
      default = "/tmp/zsh-ai-cmd.log";
      description = "Location for debug log file when debug mode is enabled.";
    };
  };

  config = mkIf cfg.enable {
    # Ensure zsh-ai-cmd package is installed
    home.packages = with pkgs; [
      zsh-ai-cmd
      curl
      jq
    ];

    # Configure zsh to load and initialize the plugin
    programs.zsh.initExtra = mkAfter ''
      # ========================================
      # ZSH AI Command Suggestions Configuration
      # ========================================

      # Load Anthropic API key from agenix secret
      if [[ -f "/run/agenix/api-anthropic" ]]; then
        export ANTHROPIC_API_KEY="$(cat /run/agenix/api-anthropic)"
      else
        echo "WARNING: Anthropic API key not found at /run/agenix/api-anthropic" >&2
        echo "zsh-ai-cmd will not function without an API key" >&2
      fi

      # Configure Claude model (if not using default)
      ${optionalString (cfg.model != "claude-haiku-4-5") ''
      export ZSH_AI_CMD_MODEL="${cfg.model}"
      ''}

      # Configure trigger key (always set to ensure correct binding)
      export ZSH_AI_CMD_KEY="${cfg.triggerKey}"

      # Enable debug logging (if requested)
      ${optionalString cfg.debug ''
      export ZSH_AI_CMD_DEBUG=true
      export ZSH_AI_CMD_LOG="${cfg.logFile}"
      echo "DEBUG: zsh-ai-cmd debug logging enabled - logs at ${cfg.logFile}" >&2
      ''}

      # Source the zsh-ai-cmd plugin
      if [[ -f "${pkgs.zsh-ai-cmd}/share/zsh/plugins/zsh-ai-cmd/zsh-ai-cmd.plugin.zsh" ]]; then
        source "${pkgs.zsh-ai-cmd}/share/zsh/plugins/zsh-ai-cmd/zsh-ai-cmd.plugin.zsh"
      else
        echo "ERROR: zsh-ai-cmd plugin not found at expected path" >&2
      fi
    '';
  };
}
