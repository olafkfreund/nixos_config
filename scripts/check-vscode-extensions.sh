#!/usr/bin/env bash
# Script to identify VS Code extensions not managed by Nix

set -euo pipefail

VSCODE_EXTENSIONS_DIR="$HOME/.vscode/extensions"
SETTINGS_JSON="$HOME/.config/Code/User/settings.json"

echo "=== VS Code Extension Analysis ==="
echo

# Check if VS Code extensions directory exists
if [[ -d "$VSCODE_EXTENSIONS_DIR" ]]; then
  echo "🔍 Extensions installed outside of Nix:"
  ls -la "$VSCODE_EXTENSIONS_DIR" | grep -E "^\d" | awk '{print $9}' | sort
  echo

  echo "📊 Total extensions outside Nix: $(ls -1 "$VSCODE_EXTENSIONS_DIR" | wc -l)"
else
  echo "✅ No extensions directory found - all managed by Nix"
fi

echo
echo "=== Settings Analysis ==="

if [[ -f "$SETTINGS_JSON" ]]; then
  echo "⚠️  VS Code is managing its own settings.json file"
  echo "📅 Last modified: $(stat -c %y "$SETTINGS_JSON")"
  echo "📏 File size: $(stat -c %s "$SETTINGS_JSON") bytes"

  echo
  echo "🔧 Extension-specific settings found:"
  grep -o '"[^"]*\.[^"]*"' "$SETTINGS_JSON" | grep -E '\.(enable|config|setting)' | sort -u | head -10
else
  echo "✅ No settings.json found - managed by Nix"
fi

echo
echo "=== Recommendations ==="
echo "1. Remove manually installed extensions: rm -rf ~/.vscode/extensions"
echo "2. Remove settings.json: rm ~/.config/Code/User/settings.json"
echo "3. Rebuild NixOS (with HM as module): sudo nixos-rebuild switch --flake ."
echo "4. For missing extensions, use buildVscodeMarketplaceExtension in your Nix config"
