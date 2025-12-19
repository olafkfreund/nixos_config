# AI-Powered Shell Command Suggestions Module
#
# Provides intelligent command suggestions using Anthropic Claude API.
# Displays suggestions as non-intrusive ghost text triggered by a keybinding.
#
# ## Features
#
# - **Ghost Text Display**: Non-intrusive suggestions using ZLE's POSTDISPLAY
# - **Context-Aware**: Includes OS type, shell, and current directory in requests
# - **Configurable**: Support for different Claude models and keybindings
# - **Secure**: API key loaded from agenix encrypted secret at runtime
# - **Debug Support**: Optional logging for troubleshooting
#
# ## Usage
#
# 1. Type a command description or partial command:
#    ```
#    list files in this directory
#    ```
#
# 2. Press Ctrl+G (or configured trigger key) to get AI suggestion:
#    ```
#    list files in this directory  ⇥  ls -la
#    ```
#
# 3. Press Tab to accept suggestion or continue typing to dismiss
#
# ## Configuration Example
#
# ```nix
# features.zsh-ai-cmd = {
#   enable = true;
#   model = "claude-3-5-sonnet-20241022";  # Optional: more powerful model
#   triggerKey = "^G";                      # Default: Ctrl+G (recommended)
#   debug = false;                          # Optional: enable logging
# };
# ```
#
# ## Requirements
#
# - Anthropic API key configured via agenix (config.age.secrets."api-anthropic")
# - curl and jq in system PATH (provided automatically)
# - Modern zsh with ZLE widget support
#
# ## Security
#
# - API key loaded from encrypted agenix secret at runtime
# - Never stored in Nix store or shell history
# - Debug logs contain API responses - disable in production
#
# ## Troubleshooting
#
# - No suggestions: Check API key exists and is readable
# - Slow responses: Normal for complex commands (30s timeout)
# - Widget conflicts: Check other plugins wrapping same ZLE widgets
# - Network issues: Verify connectivity to api.anthropic.com
#
# ## Implementation Details
#
# - Source repository: https://github.com/kylesnowschwartz/zsh-ai-cmd
# - License: MIT
# - Dependencies: curl (HTTP client), jq (JSON parser)
# - Integration: Uses existing Anthropic API infrastructure

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.zsh-ai-cmd;
in
{
  # Define zsh-ai-cmd feature options
  options.features.zsh-ai-cmd = {
    enable = mkEnableOption "AI-powered shell command suggestions using Anthropic Claude";

    model = mkOption {
      type = types.str;
      default = "claude-haiku-4-5-20251001";
      example = "claude-3-5-sonnet-20241022";
      description = ''
        Claude model to use for command suggestions.

        Available models:
        - claude-haiku-4-5-20251001 (default, fast and cost-effective)
        - claude-3-5-sonnet-20241022 (more powerful, higher cost)
        - claude-3-5-haiku-20241022 (balanced performance)

        See https://docs.anthropic.com/claude/docs/models-overview for details.
      '';
    };

    triggerKey = mkOption {
      type = types.str;
      default = "^G";
      example = "^X";
      description = ''
        Key binding to trigger AI command suggestions.

        Format: zsh key binding syntax (e.g., ^G for Ctrl+G, ^X for Ctrl+X).
        Default: Ctrl+G (recommended - doesn't conflict with job control)

        Note: Avoid ^Z (job control) and ^C (interrupt) as they're reserved by the shell.
      '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable debug logging for troubleshooting.

        WARNING: Debug logs contain full API responses and may include
        sensitive information. Only enable for troubleshooting and disable
        in production environments.

        Logs are written to the file specified in logFile option.
      '';
    };

    logFile = mkOption {
      type = types.str;
      default = "/tmp/zsh-ai-cmd.log";
      description = ''
        Location for debug log file when debug mode is enabled.

        Default: /tmp/zsh-ai-cmd.log

        Note: Ensure the directory is writable by your user account.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Install the zsh-ai-cmd package and its runtime dependencies
    environment.systemPackages = with pkgs; [
      zsh-ai-cmd
      curl
      jq
    ];

    # Configure zsh to load and initialize the plugin
    programs.zsh = {
      enable = true;

      # Load plugin after other zsh initialization
      # Using mkAfter ensures this runs after other shell configurations
      interactiveShellInit = mkAfter ''
        # ========================================
        # ZSH AI Command Suggestions Configuration
        # ========================================

        # Load Anthropic API key from agenix secret
        # This provides secure runtime loading without storing the key in Nix store
        if [[ -f "${config.age.secrets."api-anthropic".path}" ]]; then
          export ANTHROPIC_API_KEY="$(cat ${config.age.secrets."api-anthropic".path})"
        else
          echo "WARNING: Anthropic API key not found at ${config.age.secrets."api-anthropic".path}" >&2
          echo "zsh-ai-cmd will not function without an API key" >&2
        fi

        # Configure Claude model (if not using default)
        ${optionalString (cfg.model != "claude-haiku-4-5-20251001") ''
        export ZSH_AI_CMD_MODEL="${cfg.model}"
        ''}

        # Configure trigger key (always set to ensure correct binding)
        export ZSH_AI_CMD_KEY="${cfg.triggerKey}"

        # Enable debug logging (if requested)
        ${optionalString cfg.debug ''
        export ZSH_AI_CMD_DEBUG=true
        export ZSH_AI_CMD_LOG="${cfg.logFile}"

        # Warn about debug mode in interactive shells
        echo "DEBUG: zsh-ai-cmd debug logging enabled - logs at ${cfg.logFile}" >&2
        ''}

        # Source the zsh-ai-cmd plugin
        # This loads the command suggestion functionality
        if [[ -f "${pkgs.zsh-ai-cmd}/share/zsh/plugins/zsh-ai-cmd/zsh-ai-cmd.plugin.zsh" ]]; then
          source "${pkgs.zsh-ai-cmd}/share/zsh/plugins/zsh-ai-cmd/zsh-ai-cmd.plugin.zsh"
        else
          echo "ERROR: zsh-ai-cmd plugin not found at expected path" >&2
        fi
      '';
    };

    # Assertions to validate configuration
    assertions = [
      {
        assertion = config.programs.zsh.enable;
        message = "zsh-ai-cmd requires programs.zsh.enable = true";
      }
      {
        assertion = config.age.secrets ? "api-anthropic";
        message = ''
          zsh-ai-cmd requires Anthropic API key configured via agenix.

          Ensure the api-anthropic secret is configured in modules/secrets/api-keys.nix.
          The secret will be decrypted to: ${config.age.secrets."api-anthropic".path}
        '';
      }
    ];

    # Warnings for potential issues
    warnings = optional cfg.debug [
      ''
        zsh-ai-cmd debug mode is enabled. Debug logs may contain sensitive
        information including API responses. Disable debug mode in production:

        features.zsh-ai-cmd.debug = false;
      ''
    ];
  };
}
