#!/usr/bin/env bash
# Script to get SHA256 hashes for VS Code extensions

set -euo pipefail

get_extension_hash() {
    local publisher="$1"
    local name="$2"
    local version="$3"
    
    echo "Getting hash for ${publisher}.${name}@${version}..."
    
    # Download extension to get hash
    local url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${publisher}/vsextensions/${name}/${version}/vspackage"
    
    # Use nix-prefetch-url to get the hash
    nix-prefetch-url --name "${publisher}-${name}-${version}.vsix" "$url" 2>/dev/null || {
        echo "❌ Failed to get hash for ${publisher}.${name}@${version}"
        echo "   Try downloading manually and getting hash with: nix-hash --type sha256 --base32 <file>"
        return 1
    }
}

echo "🔍 Getting hashes for missing VS Code extensions..."
echo

# Google Gemini Code Assist
echo "1. Google Gemini Code Assist:"
get_extension_hash "google" "geminicodeassist" "2.36.0"
echo

# Anthropic Claude
echo "2. Anthropic Claude:"
get_extension_hash "anthropic" "claude-code" "1.0.1"
echo

# Docker
echo "3. Docker:"
get_extension_hash "docker" "docker" "0.10.0"
echo

echo "✅ Copy these hashes to your vscode.nix customExtensions section"
echo "🔧 Update the sha256 values in the buildVscodeMarketplaceExtension calls"
