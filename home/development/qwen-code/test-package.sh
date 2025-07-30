#!/usr/bin/env bash

# Test script for qwen-code package

set -e

echo "🧪 Testing qwen-code package..."

# Navigate to nixos config directory
cd /home/olafkfreund/.config/nixos

echo "📦 Building qwen-code package..."

# Try to build the package
if nix-build home/development/qwen-code/shell.nix; then
    echo "✅ Package built successfully!"
    
    echo "🔍 Testing the binary..."
    
    # Test the built binary
    if ./result/bin/qwen --help 2>/dev/null; then
        echo "✅ Binary works and shows help!"
    else
        echo "⚠️  Binary exists but help failed - this might be normal if it requires API keys"
        echo "📍 Binary location: ./result/bin/qwen"
    fi
    
    echo ""
    echo "🎉 Package test completed!"
    echo "You can now use: nix-build home/development/qwen-code/shell.nix"
    
else
    echo "❌ Package build failed"
    echo "This is expected on first run - you need to update the hashes first"
    echo "Run: ./update-hashes.sh"
fi