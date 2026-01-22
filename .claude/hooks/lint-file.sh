#!/usr/bin/env bash
# Claude Code Hook: Lint files after Write/Edit operations
# Uses Nix-packaged tools only - no npx, no external dependencies
#
# This script is called by Claude Code PostToolUse hooks
# Input: JSON on stdin with tool_input.file_path
# Exit codes:
#   0 = success (stdout shown in verbose mode)
#   2 = blocking error (action blocked)
#   other = non-blocking error

set -euo pipefail

# Read file path from JSON input
FILE_PATH=$(jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Exit if no file path or file doesn't exist
if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Skip files in certain directories
case "$FILE_PATH" in
  */.git/* | */result/* | */node_modules/* | */.direnv/*)
    exit 0
    ;;
esac

# Lint based on file extension
case "$FILE_PATH" in
  *.nix)
    # Run statix for Nix linting
    if command -v statix &>/dev/null; then
      statix check "$FILE_PATH" 2>/dev/null || true
    fi
    # Run deadnix for dead code detection
    if command -v deadnix &>/dev/null; then
      deadnix "$FILE_PATH" 2>/dev/null || true
    fi
    ;;

  *.sh | *.bash)
    if command -v shellcheck &>/dev/null; then
      # Ignore common NixOS-specific warnings
      shellcheck -e SC1091 -e SC2034 -e SC2086 "$FILE_PATH" 2>/dev/null || true
    fi
    ;;

  *.py)
    if command -v ruff &>/dev/null; then
      ruff check "$FILE_PATH" 2>/dev/null || true
    fi
    ;;

  *.yaml | *.yml)
    # Check if it's a GitHub Actions workflow
    if [[ "$FILE_PATH" == *".github/workflows/"* ]]; then
      if command -v actionlint &>/dev/null; then
        actionlint "$FILE_PATH" 2>/dev/null || true
      fi
    fi
    # General YAML linting
    if command -v yamllint &>/dev/null; then
      yamllint -d relaxed "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

exit 0
