#!/usr/bin/env bash
# Preview NixOS system updates with detailed package changes
# Uses nvd for human-readable output showing exactly what packages will change

set -euo pipefail

# ANSI color codes
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Get script and config directories
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

# Determine hostname for configuration
readonly HOSTNAME="${1:-$(hostname)}"

echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}${BOLD}  NixOS Update Preview for: ${CYAN}${HOSTNAME}${NC}"
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check if nvd is available
if ! command -v nvd &> /dev/null; then
    echo -e "${RED}✗ Error:${NC} nvd is not installed or not in PATH"
    echo -e "${YELLOW}  Install with: nix-env -i nvd${NC}"
    echo -e "${YELLOW}  Or enable nix.development.enable in your configuration${NC}"
    exit 1
fi

# Change to config directory
cd "$CONFIG_DIR"

# Step 1: Save current flake.lock
echo -e "${BLUE}[1/5]${NC} 📦 Backing up current flake.lock..."
cp flake.lock flake.lock.backup

# Step 2: Update flake inputs
echo -e "${BLUE}[2/5]${NC} 🔄 Checking for nixpkgs updates..."
if nix flake lock --update-input nixpkgs 2>&1 | grep -q "Updated"; then
    echo -e "${GREEN}  ✓ Found updates available${NC}"
else
    if diff -q flake.lock flake.lock.backup > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ System is already up to date${NC}"
        rm flake.lock.backup
        exit 0
    fi
fi

# Step 3: Show commit range
echo -e "${BLUE}[3/5]${NC} 📊 Analyzing nixpkgs changes..."
OLD_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock.backup 2>/dev/null || echo "unknown")
NEW_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock 2>/dev/null || echo "unknown")

if [[ "$OLD_REV" != "unknown" && "$NEW_REV" != "unknown" ]]; then
    echo -e "  ${CYAN}Previous:${NC} ${OLD_REV:0:12}"
    echo -e "  ${CYAN}Latest:${NC}   ${NEW_REV:0:12}"
    echo -e "  ${CYAN}GitHub:${NC}   https://github.com/NixOS/nixpkgs/compare/${OLD_REV:0:12}...${NEW_REV:0:12}"
fi

# Step 4: Build new configuration
echo -e "${BLUE}[4/5]${NC} 🔨 Building new system configuration..."
echo -e "${YELLOW}  This may take a few minutes depending on changes...${NC}"

NEW_SYSTEM=$(nix build ".#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel" \
    --no-link --print-out-paths 2>&1)

if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Build failed:${NC}"
    echo "$NEW_SYSTEM"
    echo -e "${YELLOW}  Restoring previous flake.lock...${NC}"
    mv flake.lock.backup flake.lock
    exit 1
fi

echo -e "${GREEN}  ✓ Build successful${NC}"

# Step 5: Show package changes with nvd
echo -e "${BLUE}[5/5]${NC} 📋 Package changes:"
echo

# Use nvd to show differences
nvd diff /run/current-system "$NEW_SYSTEM" || {
    echo -e "${YELLOW}  Note: Using fallback method${NC}"
    nix store diff-closures /run/current-system "$NEW_SYSTEM"
}

echo
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Preview Complete${NC}"
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  ${CYAN}•${NC} Review the changes above"
echo -e "  ${CYAN}•${NC} To apply: ${BOLD}just quick-deploy ${HOSTNAME}${NC}"
echo -e "  ${CYAN}•${NC} To revert: ${BOLD}mv flake.lock.backup flake.lock${NC}"
echo

# Check if reboot is needed
if nvd diff /run/current-system "$NEW_SYSTEM" | grep -qE '(linux-|systemd)'; then
    echo -e "${YELLOW}⚠️  System reboot recommended${NC} (kernel or systemd updated)"
    echo
fi

echo -e "${BLUE}Keeping flake.lock changes.${NC} Backup saved as ${CYAN}flake.lock.backup${NC}"
