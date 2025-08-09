#!/usr/bin/env bash

# Script to generate hashes for gemini-cli package

echo "Generating hashes for gemini-cli package..."

# Generate source hash
echo "Fetching source hash..."
SRC_HASH=$(nix-prefetch-github google-gemini gemini-cli --rev "v0.1.1" 2>/dev/null | grep sha256 | cut -d'"' -f4)

if [ -z "$SRC_HASH" ]; then
  echo "Could not fetch source hash automatically. Please run:"
  echo 'nix-prefetch-github google-gemini gemini-cli --rev "v0.1.1"'
  echo ""
  echo "Alternative method:"
  echo 'nix-prefetch-url --unpack "https://github.com/google-gemini/gemini-cli/archive/v0.1.1.tar.gz"'
else
  echo "Source hash: sha256-$SRC_HASH"
fi

echo ""
echo "To get the npmDepsHash, you'll need to:"
echo "1. Replace the source hash in default.nix"
echo "2. Run: nix-build -A gemini-cli"
echo "3. The build will fail and show you the correct npmDepsHash"
echo "4. Update the npmDepsHash in default.nix and rebuild"

echo ""
echo "Alternatively, if you have the latest Nix with flakes, you can use:"
echo 'nix run nixpkgs#prefetch-npm-deps package-lock.json'
