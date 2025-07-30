#!/usr/bin/env bash

# Script to calculate and update hashes for qwen-code package

set -e

echo "🔍 Calculating source hash for qwen-code..."

# Calculate source hash using nix-prefetch-github
echo "Fetching source hash..."
SOURCE_HASH=$(nix-prefetch-github QwenLM qwen-code --rev v0.0.1-alpha.8 2>/dev/null | jq -r .hash)

if [ -n "$SOURCE_HASH" ] && [ "$SOURCE_HASH" != "null" ]; then
    echo "✅ Source hash: $SOURCE_HASH"
    
    # Update the source hash in default.nix
    sed -i "s/hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";/hash = \"$SOURCE_HASH\";/" default.nix
    echo "✅ Updated source hash in default.nix"
else
    echo "❌ Failed to get source hash, trying alternative method..."
    
    # Alternative method using nix-prefetch-url
    TARBALL_URL="https://github.com/QwenLM/qwen-code/archive/v0.0.1-alpha.8.tar.gz"
    SOURCE_HASH=$(nix-prefetch-url --unpack "$TARBALL_URL" 2>/dev/null || echo "")
    
    if [ -n "$SOURCE_HASH" ]; then
        echo "✅ Source hash (alternative): sha256-$SOURCE_HASH"
        sed -i "s/hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";/hash = \"sha256-$SOURCE_HASH\";/" default.nix
        echo "✅ Updated source hash in default.nix"
    else
        echo "❌ Could not calculate source hash"
        exit 1
    fi
fi

echo ""
echo "🔍 Now attempting to calculate npm dependencies hash..."
echo "This will likely fail the first time - that's expected!"
echo ""

# Try to build the package to get the npm deps hash
echo "Attempting to build package (this will fail and show npm deps hash)..."

cd /home/olafkfreund/.config/nixos

# This will fail but give us the correct npmDepsHash
nix-build -A packages.x86_64-linux.qwen-code home/development/qwen-code/default.nix 2>&1 | tee /tmp/qwen-build-output.log || true

# Extract the hash from the error message
NPM_HASH=$(grep -oP 'got:\s+sha256-\K[A-Za-z0-9+/=]+' /tmp/qwen-build-output.log | head -1 || echo "")

if [ -n "$NPM_HASH" ]; then
    echo ""
    echo "✅ Found npm dependencies hash: sha256-$NPM_HASH"
    
    # Update the npm deps hash in default.nix
    sed -i "s/npmDepsHash = \"sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=\";/npmDepsHash = \"sha256-$NPM_HASH\";/" default.nix
    echo "✅ Updated npm dependencies hash in default.nix"
    
    echo ""
    echo "🚀 Hashes updated! You can now try building the package again."
    echo "Run: nix-build -A packages.x86_64-linux.qwen-code"
else
    echo ""
    echo "⚠️  Could not automatically extract npm deps hash."
    echo "Please check the build output above and manually update npmDepsHash in default.nix"
    echo "Look for a line like: 'got: sha256-...'"
fi

echo ""
echo "📁 Current default.nix content:"
echo "=================================="
head -20 default.nix
echo "=================================="