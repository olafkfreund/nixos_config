#!/usr/bin/env bash
# Claude Code Hook: Auto-format files after Write/Edit operations
# Uses Nix-packaged tools only - no npx, no external dependencies
#
# This script is called by Claude Code PostToolUse hooks
# Input: JSON on stdin with tool_input.file_path

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

# Format based on file extension
case "$FILE_PATH" in
  *.nix)
    if command -v nixpkgs-fmt &>/dev/null; then
      nixpkgs-fmt "$FILE_PATH" 2>/dev/null && echo "Formatted with nixpkgs-fmt"
    fi
    ;;

  *.sh | *.bash)
    if command -v shfmt &>/dev/null; then
      shfmt -w -i 2 -bn -ci "$FILE_PATH" 2>/dev/null && echo "Formatted with shfmt"
    fi
    ;;

  *.lua)
    if command -v stylua &>/dev/null; then
      stylua "$FILE_PATH" 2>/dev/null && echo "Formatted with stylua"
    fi
    ;;

  *.toml)
    if command -v taplo &>/dev/null; then
      taplo fmt "$FILE_PATH" 2>/dev/null && echo "Formatted with taplo"
    fi
    ;;

  *.yaml | *.yml)
    # YAML: validate but don't modify (yamllint is a linter, not formatter)
    if command -v yamllint &>/dev/null; then
      yamllint -d relaxed "$FILE_PATH" 2>/dev/null || true
    fi
    ;;

  *.json)
    if command -v jq &>/dev/null; then
      # Format JSON in place
      tmp_file="${FILE_PATH}.tmp.$$"
      if jq '.' "$FILE_PATH" >"$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$FILE_PATH"
        echo "Formatted with jq"
      else
        rm -f "$tmp_file"
      fi
    fi
    ;;

  *.md)
    if command -v markdownlint &>/dev/null; then
      markdownlint --fix "$FILE_PATH" 2>/dev/null || true
    fi
    ;;

  *.py)
    if command -v ruff &>/dev/null; then
      ruff format "$FILE_PATH" 2>/dev/null && echo "Formatted with ruff"
    fi
    ;;
esac

exit 0
