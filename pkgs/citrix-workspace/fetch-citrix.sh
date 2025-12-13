#!/usr/bin/env bash
set -euo pipefail

# Citrix Workspace Fetch Helper
# This script helps download and prepare Citrix Workspace for NixOS

VERSION="2508.10"
MAIN_TARBALL="linuxx64-${VERSION}.tar.gz"
USB_TARBALL="linuxx64-usb-${VERSION}.tar.gz"
DOWNLOAD_DIR="$(dirname "$0")"
MAIN_PATH="${DOWNLOAD_DIR}/${MAIN_TARBALL}"
USB_PATH="${DOWNLOAD_DIR}/${USB_TARBALL}"

echo "=== Citrix Workspace Download Helper ==="
echo ""
echo "Version: ${VERSION}"
echo "Target directory: ${DOWNLOAD_DIR}"
echo ""

# Check both packages
MAIN_EXISTS=false
USB_EXISTS=false

if [ -f "${MAIN_PATH}" ]; then
  MAIN_EXISTS=true
fi

if [ -f "${USB_PATH}" ]; then
  USB_EXISTS=true
fi

# If both exist, compute hashes
if [ "${MAIN_EXISTS}" = true ] && [ "${USB_EXISTS}" = true ]; then
  echo "✅ Both packages already exist:"
  echo "   - Main: ${MAIN_PATH}"
  echo "   - USB:  ${USB_PATH}"
  echo ""
  echo "Computing hashes for nix configuration..."

  echo ""
  echo "Main package hash:"
  MAIN_HASH=$(nix-prefetch-url "file://${MAIN_PATH}" 2>/dev/null)
  MAIN_SRI=$(nix hash convert --to sri --hash-algo sha256 "${MAIN_HASH}")
  echo "  ${MAIN_SRI}"

  echo ""
  echo "USB support hash:"
  USB_HASH=$(nix-prefetch-url "file://${USB_PATH}" 2>/dev/null)
  USB_SRI=$(nix hash convert --to sri --hash-algo sha256 "${USB_HASH}")
  echo "  ${USB_SRI}"

  echo ""
  echo "✅ Ready to use in NixOS configuration"
  exit 0
fi

# Show what's missing
echo "❌ Missing Citrix Workspace packages:"
echo ""
if [ "${MAIN_EXISTS}" = false ]; then
  echo "   - Main package: ${MAIN_TARBALL}"
fi
if [ "${USB_EXISTS}" = false ]; then
  echo "   - USB support: ${USB_TARBALL}"
fi
echo ""
echo "📥 Manual Download Required:"
echo ""
echo "1. Open your browser and navigate to:"
echo "   https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"
echo ""
echo "2. Accept the Citrix End User License Agreement (EULA)"
echo ""
echo "3. Download the following packages for version ${VERSION}:"
if [ "${MAIN_EXISTS}" = false ]; then
  echo "   ✗ Citrix Workspace app (Full Package): ${MAIN_TARBALL}"
fi
if [ "${USB_EXISTS}" = false ]; then
  echo "   ✗ USB Support Package:                 ${USB_TARBALL}"
fi
echo ""
echo "4. Move the downloaded files to:"
echo "   ${DOWNLOAD_DIR}/"
echo ""
echo "5. Run this script again to verify the hashes"
echo ""
echo "Note: Both packages are recommended for full functionality."
echo "      USB support enables local device redirection to remote sessions."
echo ""
echo "Alternative: If version ${VERSION} is not available, download the latest version"
echo "and update the VERSION variable in this script and default.nix."
echo ""

exit 1
