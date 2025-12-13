#!/usr/bin/env bash
set -euo pipefail

# Citrix Workspace Fetch Helper
# This script helps download and prepare Citrix Workspace for NixOS

VERSION="25.08.10.111"
TARBALL="linuxx64-${VERSION}.tar.gz"
DOWNLOAD_DIR="$(dirname "$0")"
TARBALL_PATH="${DOWNLOAD_DIR}/${TARBALL}"

echo "=== Citrix Workspace Download Helper ==="
echo ""
echo "Version: ${VERSION}"
echo "Target directory: ${DOWNLOAD_DIR}"
echo ""

# Check if tarball exists
if [ -f "${TARBALL_PATH}" ]; then
  echo "✅ Package already exists:"
  echo "   - ${TARBALL_PATH}"
  echo ""
  echo "Computing hash for nix configuration..."

  echo ""
  HASH=$(nix-prefetch-url "file://${TARBALL_PATH}" 2>/dev/null)
  SRI_HASH=$(nix hash convert --to sri --hash-algo sha256 "${HASH}")
  echo "SHA256 hash: ${SRI_HASH}"

  echo ""
  echo "✅ Ready to use in NixOS configuration"
  echo ""
  echo "Next step: Run the update script to automatically update configuration:"
  echo "  ./pkgs/citrix-workspace/update-hashes.sh ${SRI_HASH}"
  exit 0
fi

# Show what's missing
echo "❌ Missing Citrix Workspace package!"
echo ""
echo "📥 Manual Download Required:"
echo ""
echo "1. Open your browser and navigate to:"
echo "   https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"
echo ""
echo "2. Accept the Citrix End User License Agreement (EULA)"
echo ""
echo "3. Download the Citrix Workspace app for version ${VERSION}:"
echo "   ✗ Citrix Workspace app (Full Package - tar.gz): ${TARBALL}"
echo ""
echo "   Note: USB support is included in the main package."
echo "         Do NOT download the separate .deb USB package."
echo ""
echo "4. Move the downloaded file to:"
echo "   ${DOWNLOAD_DIR}/"
echo ""
echo "5. Run this script again to compute the hash"
echo ""
echo "Alternative: If version ${VERSION} is not available, download the latest version"
echo "and update the VERSION variable in this script, default.nix, and the overlay."
echo ""

exit 1
