#!/usr/bin/env bash

# Script to check for NixOS updates and display them in a table format
# Created: May 2025

# Enable debug output
set -e
# set -x  # Uncomment for verbose debugging

# ANSI color codes for pretty output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Check for required commands
for cmd in jq nix column; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}Error:${NC} $cmd is required but not installed. Please install it first."
    exit 1
  fi
done

echo -e "${BLUE}${BOLD}Starting NixOS update check script${NC}"

# Get script directory (for cases when script is called from another directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
echo "Script directory: $SCRIPT_DIR"
echo "Config directory: $CONFIG_DIR"

# Check if running from nixos config directory
if [[ ! -f "$CONFIG_DIR/flake.lock" || ! -f "$CONFIG_DIR/flake.nix" ]]; then
  echo -e "${YELLOW}Warning:${NC} This script should be run from your NixOS config directory."
  echo "Current directory: $(pwd)"
  echo "Looking for flake files in: $CONFIG_DIR"
  exit 1
fi

echo -e "${BLUE}${BOLD}Checking for NixOS updates...${NC}"
echo "This might take a while depending on the number of inputs in your flake..."

TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

echo "Running nix flake update (might take a few minutes)..."
(cd "$CONFIG_DIR" && nix flake update --output-lock-file "$TEMP_DIR/flake.lock.new") 2>"$TEMP_DIR/update-error.log" || {
  echo -e "${RED}Error running nix flake update:${NC}"
  cat "$TEMP_DIR/update-error.log"
  rm -rf "$TEMP_DIR"
  exit 1
}
echo "Finished checking for updates"

echo -e "${BLUE}${BOLD}Analyzing updates...${NC}"
NEW_LOCK=$(jq -r '.nodes' "$TEMP_DIR/flake.lock.new")
OLD_LOCK=$(jq -r '.nodes' "$CONFIG_DIR/flake.lock")

# Extract information and format as a table
echo -e "${GREEN}${BOLD}NixOS Update Information:${NC}"
echo

# Table header
printf "%-25s %-15s %-15s %s\n" "Input" "Current" "Latest" "URL"
printf "%-25s %-15s %-15s %s\n" "$(printf '=%.0s' {1..25})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..50})"

# Get all inputs
inputs=$(echo "$OLD_LOCK" | jq -r 'keys[]')
echo "Found $(echo "$inputs" | wc -l) inputs to check"

# Count for updated packages
updates_count=0

# For each input, compare versions
for input in $inputs; do
  # Skip certain inputs if needed
  if [[ "$input" == "root" ]]; then
    continue
  fi

  # Get current version
  current=$(echo "$OLD_LOCK" | jq -r --arg input "$input" '.[$input].original.rev // .[$input].locked.rev // "N/A"')
  current_short=${current:0:8}

  # Get new version
  latest=$(echo "$NEW_LOCK" | jq -r --arg input "$input" '.[$input].original.rev // .[$input].locked.rev // "N/A"')
  latest_short=${latest:0:8}

  # Get URL
  url=$(echo "$OLD_LOCK" | jq -r --arg input "$input" '.[$input].locked.url // .[$input].original.url // "N/A"')

  # Format and display
  if [[ "$current" != "$latest" && "$current" != "N/A" && "$latest" != "N/A" ]]; then
    printf "%-25s ${RED}%-15s${NC} ${GREEN}%-15s${NC} %s\n" "$input" "$current_short" "$latest_short" "$url"
    updates_count=$((updates_count + 1))
  else
    printf "%-25s %-15s %-15s %s\n" "$input" "$current_short" "$latest_short" "$url"
  fi
done

# Summary
echo
echo -e "${BLUE}${BOLD}Summary:${NC} $updates_count packages can be updated"

# Add option to apply updates
echo
echo -e "${YELLOW}${BOLD}To apply these updates:${NC}"
echo "  cd $CONFIG_DIR && nix flake update"
echo
echo -e "${YELLOW}${BOLD}To update specific input:${NC}"
echo "  cd $CONFIG_DIR && nix flake lock --update-input <input-name>"

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo -e "${GREEN}${BOLD}Done!${NC}"
exit 0
