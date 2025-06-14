#!/usr/bin/env bash
# Script to clean VS Code and rebuild with Nix-managed configuration

set -euo pipefail

echo "🧹 Cleaning VS Code configuration..."

# Stop VS Code if running
echo "⏹️  Stopping VS Code..."
pkill -f "code" || true
sleep 2

# Backup current settings
if [[ -f ~/.config/Code/User/settings.json ]]; then
    echo "💾 Backing up current settings.json..."
    cp ~/.config/Code/User/settings.json ~/.config/Code/User/settings.json.backup.$(date +%Y%m%d_%H%M%S)
fi

# Remove manually installed extensions
echo "🗑️  Removing manually installed extensions..."
if [[ -d ~/.vscode/extensions ]]; then
    # Keep only Nix-managed extensions (symlinks)
    find ~/.vscode/extensions -maxdepth 1 -type d ! -name "extensions" ! -name ".*" -exec rm -rf {} + 2>/dev/null || true
    # Remove manually installed extension files
    find ~/.vscode/extensions -maxdepth 1 -type f -name "*.json" ! -name ".extensions-immutable.json" -delete 2>/dev/null || true
fi

# Remove VS Code user settings that conflict with Nix
echo "🔧 Removing conflicting settings..."
rm -f ~/.config/Code/User/settings.json

# Clear VS Code workspace state
echo "🗂️  Clearing workspace state..."
rm -rf ~/.config/Code/User/workspaceStorage/* 2>/dev/null || true
rm -rf ~/.config/Code/CachedExtensions/* 2>/dev/null || true

echo "🏗️  Rebuilding NixOS configuration (with Home Manager module)..."
cd /home/olafkfreund/.config/nixos
sudo nixos-rebuild switch --flake .

echo "✅ Cleanup complete!"
echo ""
echo "📋 Manual steps required:"
echo "1. Add missing extensions to your vscode.nix using buildVscodeMarketplaceExtension"
echo "2. Start VS Code and verify settings are managed by Nix"
echo "3. If you need specific extensions, install them through Nix configuration"
echo ""
echo "🚨 Extensions that need to be added to Nix config:"
echo "   - google.geminicodeassist"
echo "   - anthropic.claude-code"  
echo "   - docker.docker"
echo "   - ms-python.python"
echo "   - saoudrizwan.claude-dev"
