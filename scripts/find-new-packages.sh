#!/usr/bin/env bash
# Find newly added packages in nixpkgs between two revisions
# Useful for discovering what's available in the latest nixpkgs

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

echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}${BOLD}  Finding New Packages in nixpkgs${NC}"
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Change to config directory
cd "$CONFIG_DIR"

# Get current and previous nixpkgs revisions from flake.lock
if [[ -f flake.lock.backup ]]; then
    OLD_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock.backup 2>/dev/null)
    NEW_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock 2>/dev/null)

    if [[ -z "$OLD_REV" || "$OLD_REV" == "null" ]]; then
        echo -e "${YELLOW}⚠  No previous flake.lock.backup found${NC}"
        echo -e "${YELLOW}   Run './scripts/preview-updates.sh' first to create backup${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠  No flake.lock.backup found${NC}"
    echo -e "${YELLOW}   This script works after running preview-updates.sh${NC}"
    echo
    echo -e "${BLUE}Attempting to use git history instead...${NC}"

    # Try to get last committed version
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        OLD_REV=$(git show HEAD:flake.lock 2>/dev/null | jq -r '.nodes.nixpkgs.locked.rev' 2>/dev/null || echo "")
        NEW_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock 2>/dev/null)

        if [[ -z "$OLD_REV" ]]; then
            echo -e "${RED}✗ Could not determine previous nixpkgs revision${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Not in a git repository and no backup found${NC}"
        exit 1
    fi
fi

echo -e "${CYAN}Previous revision:${NC} ${OLD_REV:0:12}"
echo -e "${CYAN}Current revision:${NC}  ${NEW_REV:0:12}"
echo

if [[ "$OLD_REV" == "$NEW_REV" ]]; then
    echo -e "${GREEN}✓ No changes in nixpkgs${NC}"
    exit 0
fi

# Create temporary directory for analysis
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${BLUE}[1/4]${NC} 📥 Fetching nixpkgs repository (this may take a moment)..."

# Clone minimal nixpkgs for analysis
if ! git clone --depth 1000 --no-checkout https://github.com/NixOS/nixpkgs.git "$TEMP_DIR/nixpkgs" &>/dev/null; then
    echo -e "${RED}✗ Failed to clone nixpkgs repository${NC}"
    exit 1
fi

cd "$TEMP_DIR/nixpkgs"

# Fetch the specific commits we need
echo -e "${BLUE}[2/4]${NC} 🔍 Fetching specific commits..."
git fetch origin "$OLD_REV" "$NEW_REV" &>/dev/null || {
    echo -e "${RED}✗ Failed to fetch commits${NC}"
    exit 1
}

echo -e "${BLUE}[3/4]${NC} 🆕 Finding new packages..."

# Find new package directories (looking for new default.nix files)
NEW_PACKAGES=$(git diff --name-status "$OLD_REV" "$NEW_REV" -- pkgs/ | \
    grep -E '^A.*/(default\.nix|package\.nix)$' | \
    awk '{print $2}' | \
    sed 's|/default\.nix$||; s|/package\.nix$||' | \
    sed 's|^pkgs/||' | \
    sort -u)

# Count new packages
NEW_COUNT=$(echo "$NEW_PACKAGES" | grep -c . || echo "0")

echo -e "${BLUE}[4/4]${NC} 📊 Analyzing results..."
echo

if [[ "$NEW_COUNT" -gt 0 ]]; then
    echo -e "${GREEN}${BOLD}Found ${NEW_COUNT} new packages:${NC}"
    echo

    # Display in a nice format
    echo "$NEW_PACKAGES" | head -50 | nl -w2 -s'. ' | while read line; do
        echo -e "  ${CYAN}${line}${NC}"
    done

    if [[ "$NEW_COUNT" -gt 50 ]]; then
        echo
        echo -e "${YELLOW}  ... and $((NEW_COUNT - 50)) more packages${NC}"
        echo -e "${YELLOW}  Full list saved to: ${CYAN}${TEMP_DIR}/new-packages.txt${NC}"
        echo "$NEW_PACKAGES" > "${CONFIG_DIR}/new-packages.txt"
    fi

    echo
    echo -e "${BLUE}${BOLD}Top Categories:${NC}"
    echo "$NEW_PACKAGES" | cut -d'/' -f1 | sort | uniq -c | sort -rn | head -5 | \
        awk '{printf "  %s%-20s %s%3d packages%s\n", "'${CYAN}'", $2, "'${NC}'", $1, ""}'

else
    echo -e "${GREEN}✓ No new packages found between these revisions${NC}"
fi

echo
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}View full changelog:${NC}"
echo -e "  https://github.com/NixOS/nixpkgs/compare/${OLD_REV:0:12}...${NEW_REV:0:12}"
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
