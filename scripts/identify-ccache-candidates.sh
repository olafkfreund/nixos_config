#!/usr/bin/env bash
# Script to identify packages that would benefit from ccache
# Usage: ./identify-ccache-candidates.sh

set -euo pipefail

echo "=== Analyzing Build Times for ccache Candidates ==="
echo ""

# Check if nix build logs exist
if [ ! -d "/nix/var/log/nix" ]; then
  echo "Warning: Nix build logs not found"
fi

echo "Method 1: Analyze recent builds from Nix store"
echo "─────────────────────────────────────────────────"

# Find packages that took longest to build
nix path-info --all --json | jq -r '
  .[] |
  select(.narSize > 100000000) |
  "\(.path) \(.narSize)"
' | sort -k2 -rn | head -20 | while read -r path size; do
  pkg_name=$(basename "$path" | cut -d'-' -f2-)
  size_mb=$((size / 1048576))
  echo "  📦 $pkg_name (${size_mb}MB)"
done

echo ""
echo "Method 2: Check current system packages"
echo "─────────────────────────────────────────────────"

# Get all packages in current generation
nix-store -qR /run/current-system | grep -E '\-gcc-|\-clang-|\-qt-|\-kde-|\-firefox-|\-chromium-|\-kernel-|\-mesa-|\-rocm-|\-cuda-' | while read -r pkg; do
  pkg_name=$(basename "$pkg" | cut -d'-' -f2-)
  echo "  🔧 $pkg_name (C/C++ package)"
done

echo ""
echo "Method 3: Hardware-specific packages (your infrastructure)"
echo "─────────────────────────────────────────────────"

# P620 specific (AMD ROCm)
echo "  P620 (AMD GPU):"
echo "    - rocm (hours to build)"
echo "    - mesa (GPU drivers)"
echo "    - linux kernel (if custom)"

# Razer/P510 (NVIDIA)
echo ""
echo "  Razer/P510 (NVIDIA GPU):"
echo "    - cudaPackages"
echo "    - nvidia drivers (if from source)"

# Development packages
echo ""
echo "  Development (all hosts):"
echo "    - Qt applications (VS Code, desktop apps)"
echo "    - Browsers (firefox, chromium)"
echo "    - Language toolchains (gcc, clang, rust)"

echo ""
echo "=== Recommended ccache Candidates ==="
echo "─────────────────────────────────────────────────"
echo ""
echo "HIGH PRIORITY (most build time savings):"
echo "  1. rocm (P620 only) - hours → minutes"
echo "  2. linux kernel (if custom builds)"
echo "  3. Qt-based applications"
echo "  4. chromium/firefox (if building from source)"
echo ""
echo "MEDIUM PRIORITY:"
echo "  5. mesa/graphics drivers"
echo "  6. Large C++ projects (KDE apps, etc.)"
echo "  7. Language toolchains (gcc, llvm)"
echo ""
echo "LOW PRIORITY (limited benefit):"
echo "  8. Small utilities"
echo "  9. Already cached by binary cache"
echo ""
echo "=== Cache Hit Rate Estimation ==="
echo "─────────────────────────────────────────────────"
echo ""
echo "Expected cache hit rates WITH proper configuration:"
echo "  - ROCm rebuilds: 80-95% (minor changes)"
echo "  - Kernel rebuilds: 70-90% (config changes)"
echo "  - Qt applications: 60-80% (dependency updates)"
echo ""
echo "Expected cache hit rates WITHOUT CCACHE_SLOPPINESS:"
echo "  - All packages: 0.35% (basically useless)"
echo ""
