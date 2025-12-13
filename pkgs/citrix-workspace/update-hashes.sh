#!/usr/bin/env bash
set -euo pipefail

# Citrix Workspace Hash Update Helper
# This script automatically updates SHA256 hashes in configuration files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "=== Citrix Workspace Hash Update Helper ==="
echo ""

# Check if tarball exists
TARBALL="${SCRIPT_DIR}/linuxx64-25.08.10.111.tar.gz"

if [ ! -f "${TARBALL}" ]; then
  echo "❌ Error: Tarball not found!"
  echo ""
  echo "Please run: ./pkgs/citrix-workspace/fetch-citrix.sh"
  echo "And download the required file first."
  exit 1
fi

echo "✅ Found tarball: ${TARBALL}"
echo ""

# Compute hash
echo "Computing SHA256 hash..."
HASH=$(nix-prefetch-url "file://${TARBALL}" 2>/dev/null)
SRI_HASH=$(nix hash convert --to sri --hash-algo sha256 "${HASH}")

echo ""
echo "Package hash: ${SRI_HASH}"
echo ""

# Update overlay file
OVERLAY_FILE="${ROOT_DIR}/overlays/citrix-workspace.nix"
echo "Updating: ${OVERLAY_FILE}"

# Escape forward slashes in hash for sed
SRI_ESCAPED=$(echo "${SRI_HASH}" | sed 's/\//\\\//g')

# Update hash in overlay
sed -i "s/sha256 = \"0\{52\}\";/sha256 = \"${SRI_ESCAPED}\";/" "${OVERLAY_FILE}"

echo "✅ Updated overlay hash"

# Update package definition file
PKG_FILE="${SCRIPT_DIR}/default.nix"
echo "Updating: ${PKG_FILE}"

# Update hash in package definition
sed -i "s/sha256 = \"sha256-A\{43\}=\";/sha256 = \"${SRI_ESCAPED}\";/" "${PKG_FILE}"

echo "✅ Updated package definition hash"
echo ""

echo "🎉 All hashes updated successfully!"
echo ""
echo "Next steps:"
echo "1. Commit the changes:"
echo "   git add overlays/citrix-workspace.nix pkgs/citrix-workspace/default.nix"
echo "   git commit -m \"chore(citrix): update hashes for version 2508.10\""
echo ""
echo "2. Enable Citrix on desired hosts (if not already enabled)"
echo ""
echo "3. Deploy:"
echo "   just quick-deploy p620"
echo "   just quick-deploy razer"
echo ""
