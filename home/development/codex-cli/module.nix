{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.programs.codex-cli;

  # Use nixpkgs's `codex` package (Rust-based, upstream-maintained).
  # We previously vendored an npm-based @openai/codex 0.46.0 derivation;
  # OpenAI rewrote codex in Rust mid-2025 and nixpkgs tracks it, so we
  # just consume that and stop maintaining our own packaging.
  codex-cli = pkgs.codex;
in
{
  options.programs.codex-cli = {
    enable = mkEnableOption "OpenAI Codex CLI";

    package = mkOption {
      type = types.package;
      default = codex-cli;
      description = "The codex-cli package to use";
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
        # `codex` is the real binary name in nixpkgs#codex; keep the rest
        # as convenience aliases so existing muscle memory still works.
        ai-code = "codex";
        openai-codex = "codex";
      };
      description = "Shell aliases for codex";
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

          CODEX_BIN="${cfg.package}/bin/codex"
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

            # Rust codex has no --context-file; it appends piped stdin to the
            # prompt as a <stdin> block. Feed the gathered context that way.
            "$CODEX_BIN" exec "$query" < "$context_file"
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

    # NOTE: codex (the Rust CLI) self-manages its config + state under
    # $CODEX_HOME (~/.codex/config.toml), which it writes itself (personality,
    # per-project trust_level, sessions, auth.json). We deliberately do NOT
    # generate a config file here — the old ~/.config/codex/config.json was
    # silently ignored by this codex. Settings belong in ~/.codex/config.toml.

    # Shell aliases
    programs = {
      zsh.shellAliases = mkIf config.programs.zsh.enable cfg.shellAliases;
      bash.shellAliases = mkIf config.programs.bash.enable cfg.shellAliases;
      fish.shellAliases = mkIf config.programs.fish.enable cfg.shellAliases;
    };
  };
}
