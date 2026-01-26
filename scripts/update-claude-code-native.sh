#!/usr/bin/env bash
# Update script for claude-code-native package
# Usage: ./scripts/update-claude-code-native.sh [version]
#
# This script fetches the latest version and calculates hashes for the native binary.
# If no version is specified, it uses the stable version.

set -euo pipefail

GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
PKG_DIR="$(dirname "$0")/../pkgs/claude-code-native"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Get stable version from distribution channel
get_stable_version() {
  info "Fetching stable version..."
  curl -fsSL "$GCS_BUCKET/stable" 2>/dev/null || error "Failed to fetch stable version"
}

# Get latest version from distribution channel
get_latest_version() {
  info "Fetching latest version..."
  curl -fsSL "$GCS_BUCKET/latest" 2>/dev/null || error "Failed to fetch latest version"
}

# Get manifest for a version
get_manifest() {
  local version="$1"
  info "Fetching manifest for version $version..."
  curl -fsSL "$GCS_BUCKET/$version/manifest.json" 2>/dev/null || error "Failed to fetch manifest"
}

# Calculate SRI hash for a URL
calculate_hash() {
  local url="$1"
  local platform="$2"

  info "Downloading $platform binary..."

  # Create temp file
  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN

  if curl -fsSL "$url" -o "$tmpfile" 2>/dev/null; then
    # Calculate SRI hash
    local hash
    hash=$(nix hash file --sri "$tmpfile" 2>/dev/null)
    local size
    size=$(stat -c %s "$tmpfile" 2>/dev/null || stat -f %z "$tmpfile" 2>/dev/null)
    echo "$hash|$size"
  else
    warn "Failed to download $platform binary"
    echo ""
  fi
}

# Main update logic
main() {
  local version="${1:-}"

  echo -e "${BLUE}=========================================="
  echo "Claude Code Native Binary Update Tool"
  echo -e "==========================================${NC}"
  echo ""

  # Show available versions
  local stable_ver latest_ver
  stable_ver=$(get_stable_version)
  latest_ver=$(get_latest_version)

  echo ""
  echo "Available versions:"
  echo "  Stable: $stable_ver"
  echo "  Latest: $latest_ver"
  echo ""

  # Use provided version or default to stable
  if [ -z "$version" ]; then
    version="$stable_ver"
    info "Using stable version: $version"
  else
    info "Using specified version: $version"
  fi

  echo ""

  # Get manifest to verify version exists
  local manifest
  manifest=$(get_manifest "$version")
  if [ -z "$manifest" ]; then
    error "Version $version not found"
  fi

  # Extract checksums from manifest (for verification)
  local x64_manifest_checksum arm64_manifest_checksum
  x64_manifest_checksum=$(echo "$manifest" | jq -r '.platforms["linux-x64"].checksum // empty' 2>/dev/null)
  arm64_manifest_checksum=$(echo "$manifest" | jq -r '.platforms["linux-arm64"].checksum // empty' 2>/dev/null)

  echo "Manifest checksums (SHA256):"
  echo "  linux-x64:   ${x64_manifest_checksum:-NOT AVAILABLE}"
  echo "  linux-arm64: ${arm64_manifest_checksum:-NOT AVAILABLE}"
  echo ""

  # Calculate SRI hashes
  local x64_url="${GCS_BUCKET}/${version}/linux-x64/claude"
  local arm64_url="${GCS_BUCKET}/${version}/linux-arm64/claude"

  local x64_result arm64_result
  x64_result=$(calculate_hash "$x64_url" "x86_64-linux")
  arm64_result=$(calculate_hash "$arm64_url" "aarch64-linux")

  # Parse results
  local x64_hash x64_size arm64_hash arm64_size
  x64_hash=$(echo "$x64_result" | cut -d'|' -f1)
  x64_size=$(echo "$x64_result" | cut -d'|' -f2)
  arm64_hash=$(echo "$arm64_result" | cut -d'|' -f1)
  arm64_size=$(echo "$arm64_result" | cut -d'|' -f2)

  echo ""
  echo -e "${GREEN}=========================================="
  echo "Update Results"
  echo -e "==========================================${NC}"
  echo ""
  echo "Version: $version"
  echo ""

  if [ -n "$x64_hash" ]; then
    echo "x86_64-linux:"
    echo "  URL:  $x64_url"
    echo "  Hash: $x64_hash"
    echo "  Size: $x64_size bytes"
  else
    echo "x86_64-linux: NOT AVAILABLE"
  fi
  echo ""

  if [ -n "$arm64_hash" ]; then
    echo "aarch64-linux:"
    echo "  URL:  $arm64_url"
    echo "  Hash: $arm64_hash"
    echo "  Size: $arm64_size bytes"
  else
    echo "aarch64-linux: NOT AVAILABLE"
  fi
  echo ""

  # Generate Nix snippet
  if [ -n "$x64_hash" ] || [ -n "$arm64_hash" ]; then
    echo -e "${BLUE}=========================================="
    echo "Nix Expression Update"
    echo -e "==========================================${NC}"
    echo ""
    echo "Update pkgs/claude-code-native/default.nix with:"
    echo ""
    echo "  version = \"$version\";"
    echo ""
    echo "  sources = {"
    if [ -n "$x64_hash" ]; then
      echo "    x86_64-linux = {"
      echo "      url = \"\${gcs_bucket}/\${version}/linux-x64/claude\";"
      echo "      hash = \"$x64_hash\";"
      echo "    };"
    fi
    if [ -n "$arm64_hash" ]; then
      echo "    aarch64-linux = {"
      echo "      url = \"\${gcs_bucket}/\${version}/linux-arm64/claude\";"
      echo "      hash = \"$arm64_hash\";"
      echo "    };"
    fi
    echo "  };"
    echo ""
  else
    error "No binaries found for version $version"
  fi
}

main "$@"
