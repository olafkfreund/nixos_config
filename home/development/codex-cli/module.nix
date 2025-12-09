{ config, lib, pkgs, ... }:

with lib;
let
  inherit (lib) types;
  cfg = config.programs.codex-cli;

  codex-cli = pkgs.callPackage ./. { inherit (pkgs) nodejs_22; };

  # Note: Configuration template available but using inline generation instead
  # configFile = pkgs.writeText "codex-config.json" (builtins.toJSON {
  #   model = cfg.defaultModel;
  #   temperature = cfg.temperature;
  #   max_tokens = cfg.maxTokens;
  #   timeout = cfg.timeout;
  #   auto_save = cfg.autoSave;
  #   syntax_highlighting = cfg.syntaxHighlighting;
  #   interactive_mode = cfg.interactiveMode;
  # });

in
{
  options.programs.codex-cli = {
    enable = mkEnableOption "OpenAI Codex CLI";

    package = mkOption {
      type = types.package;
      default = codex-cli;
      description = "The codex-cli package to use";
    };

    defaultModel = mkOption {
      type = types.str;
      default = "gpt-4";
      description = "Default model to use for code generation";
      example = "gpt-3.5-turbo";
    };

    temperature = mkOption {
      type = types.float;
      default = 0.1;
      description = "Temperature setting for code generation (0.0-1.0)";
    };

    maxTokens = mkOption {
      type = types.int;
      default = 2048;
      description = "Maximum tokens per response";
    };

    timeout = mkOption {
      type = types.int;
      default = 30;
      description = "Request timeout in seconds";
    };

    autoSave = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically save generated code";
    };

    syntaxHighlighting = mkOption {
      type = types.bool;
      default = true;
      description = "Enable syntax highlighting in output";
    };

    interactiveMode = mkOption {
      type = types.bool;
      default = true;
      description = "Enable interactive mode by default";
    };

    apiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing OpenAI API key";
      example = "/run/agenix/api-openai";
    };

    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = {
        codex = "codex-cli";
        ai-code = "codex-cli";
        openai-codex = "codex-cli";
      };
      description = "Shell aliases for codex-cli";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional configuration options";
      example = {
        editor = "nvim";
        project_templates = true;
      };
    };
  };

  config = mkIf cfg.enable {
    home = {
      packages = [ cfg.package ];

      # Set up API key if provided
      sessionVariables = mkIf (cfg.apiKeyFile != null) {
        OPENAI_API_KEY = "$(cat ${cfg.apiKeyFile})";
      };

      # Integration script for development workflow
      file.".local/bin/codex-project" = {
        text = ''
          #!/usr/bin/env bash
          # OpenAI Codex project integration script

          set -euo pipefail

          CODEX_BIN="${cfg.package}/bin/codex-cli"
          PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

          # Function to analyze project context
          analyze_project() {
            echo "Analyzing project context..."

            # Detect project type
            if [[ -f "package.json" ]]; then
              echo "Detected: Node.js project"
            elif [[ -f "Cargo.toml" ]]; then
              echo "Detected: Rust project"
            elif [[ -f "go.mod" ]]; then
              echo "Detected: Go project"
            elif [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]]; then
              echo "Detected: Python project"
            elif [[ -f "flake.nix" ]]; then
              echo "Detected: Nix project"
            else
              echo "Detected: Generic project"
            fi
          }

          # Function to run codex with project context
          codex_with_context() {
            local query="$1"
            local context_file=$(mktemp)

            # Build context information
            {
              echo "Project: $(basename "$PROJECT_ROOT")"
              echo "Path: $PROJECT_ROOT"
              echo "Language/Framework: $(analyze_project | tail -1)"
              echo "Files in project:"
              find . -type f -name "*.rs" -o -name "*.go" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.nix" | head -20
              echo ""
              echo "Query: $query"
            } > "$context_file"

            "$CODEX_BIN" --context-file "$context_file" "$query"
            rm "$context_file"
          }

          case "''${1:-help}" in
            analyze)
              analyze_project
              ;;
            ask)
              shift
              codex_with_context "$*"
              ;;
            help)
              echo "Usage: codex-project <command>"
              echo "Commands:"
              echo "  analyze  - Analyze current project"
              echo "  ask      - Ask codex with project context"
              echo "  help     - Show this help"
              ;;
            *)
              "$CODEX_BIN" "$@"
              ;;
          esac
        '';
        executable = true;
      };

      # Development environment integration
      sessionPath = [ "$HOME/.local/bin" ];
    };

    # Create configuration directory and file
    xdg.configFile."codex/config.json" = {
      source = pkgs.writeText "codex-config.json" (builtins.toJSON (
        {
          model = cfg.defaultModel;
          inherit (cfg) temperature;
          max_tokens = cfg.maxTokens;
          inherit (cfg) timeout;
          auto_save = cfg.autoSave;
          syntax_highlighting = cfg.syntaxHighlighting;
          interactive_mode = cfg.interactiveMode;
        } // cfg.extraConfig
      ));
    };

    # Shell aliases
    programs = {
      zsh.shellAliases = mkIf config.programs.zsh.enable cfg.shellAliases;
      bash.shellAliases = mkIf config.programs.bash.enable cfg.shellAliases;
      fish.shellAliases = mkIf config.programs.fish.enable cfg.shellAliases;
    };
  };
}
