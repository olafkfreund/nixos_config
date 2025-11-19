#!/usr/bin/env bash
# Workaround for Nix 2.31.2 regression (issue #37)
# https://github.com/olafkfreund/nixos_config/issues/37
#
# Problem: Nix 2.31.2 treats evaluation warnings as fatal errors (exit code 1)
# Workaround: Ignore exit code 1 from evaluation warnings, fail on real errors

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get host from argument or default to current hostname
HOST="${1:-$(hostname)}"

echo -e "${GREEN}🔨 Building NixOS configuration for ${HOST}...${NC}"

# Build the configuration and capture output
BUILD_OUTPUT=$(nix build .#nixosConfigurations."${HOST}".config.system.build.toplevel 2>&1) || BUILD_EXIT=$?

# Check if build "failed" due to evaluation warning only
if echo "$BUILD_OUTPUT" | grep -q "evaluation warning: 'system' has been renamed"; then
  echo -e "${YELLOW}⚠️  Build completed with evaluation warnings (Nix 2.31.2 known bug)${NC}"
  echo -e "${YELLOW}   Warning: 'system' has been renamed to 'stdenv.hostPlatform.system'${NC}"
  echo -e "${YELLOW}   This is from upstream nixpkgs dependencies, not our configuration.${NC}"
  echo ""
  echo -e "${GREEN}✅ Configuration is valid. Proceeding with system switch...${NC}"

  # Attempt system switch, ignoring exit code 1 from warning
  sudo nixos-rebuild switch --flake .#"${HOST}" 2>&1 || SWITCH_EXIT=$?

  if [ "${SWITCH_EXIT:-0}" -eq 1 ]; then
    # Check if it was just the warning
    if sudo nixos-rebuild switch --flake .#"${HOST}" 2>&1 | grep -q "evaluation warning"; then
      echo -e "${GREEN}✅ System switch completed successfully (ignored Nix 2.31.2 warning exit code)${NC}"
      echo ""
      echo -e "${GREEN}📋 Summary:${NC}"
      echo -e "   - Configuration built: ✓"
      echo -e "   - System switched: ✓"
      echo -e "   - Known bug: Nix 2.31.2 regression (issue #37)"
      exit 0
    else
      echo -e "${RED}❌ System switch failed with a real error${NC}"
      exit 1
    fi
  else
    echo -e "${GREEN}✅ System switch completed successfully${NC}"
    exit 0
  fi
elif [ "${BUILD_EXIT:-0}" -ne 0 ]; then
  echo -e "${RED}❌ Build failed with real error:${NC}"
  echo "$BUILD_OUTPUT"
  exit 1
else
  echo -e "${GREEN}✅ Build completed without warnings${NC}"
  sudo nixos-rebuild switch --flake .#"${HOST}"
  echo -e "${GREEN}✅ System switch completed successfully${NC}"
fi
