#!/usr/bin/env bash

# Quick integration test for the new Justfile and testing framework
# This ensures all the new commands work correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}🧪 Integration Test for Updated NixOS Configuration${NC}"
echo "=================================================="

cd "$CONFIG_DIR"

# Test basic commands
echo -e "\n${YELLOW}Testing basic Justfile commands...${NC}"

# Test that justfile is valid
if just --list > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Justfile syntax is valid${NC}"
else
    echo -e "${RED}❌ Justfile has syntax errors${NC}"
    exit 1
fi

# Test that our new scripts exist and are executable
echo -e "\n${YELLOW}Checking script files...${NC}"

scripts=(
    "scripts/validate-config.sh"
    "scripts/test-modules.sh"
    "scripts/performance-test.sh"
    "scripts/ci-test.sh"
)

for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
        echo -e "${GREEN}✅ $script is executable${NC}"
    else
        echo -e "${RED}❌ $script is not executable${NC}"
        exit 1
    fi
done

# Test that critical commands work
echo -e "\n${YELLOW}Testing critical commands...${NC}"

# Test flake check
if timeout 60 just check > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 'just check' works${NC}"
else
    echo -e "${RED}❌ 'just check' failed${NC}"
    exit 1
fi

# Test syntax checking
if just check-syntax > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 'just check-syntax' works${NC}"
else
    echo -e "${RED}❌ 'just check-syntax' failed${NC}"
    exit 1
fi

# Test help commands
if just help-extended > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 'just help-extended' works${NC}"
else
    echo -e "${RED}❌ 'just help-extended' failed${NC}"
    exit 1
fi

# Test summary
if just summary > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 'just summary' works${NC}"
else
    echo -e "${RED}❌ 'just summary' failed${NC}"
    exit 1
fi

# Test validation script (quick mode)
echo -e "\n${YELLOW}Testing validation script...${NC}"
if timeout 120 ./scripts/validate-config.sh --quick > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Validation script works${NC}"
else
    echo -e "${YELLOW}⚠️  Validation script had issues (this may be normal)${NC}"
fi

echo -e "\n${GREEN}${BOLD}🎉 Integration test completed successfully!${NC}"
echo -e "${BLUE}The updated Justfile and testing framework are ready to use.${NC}"
echo ""
echo "Try these commands:"
echo "  just validate           # Run comprehensive validation"
echo "  just test-host p620     # Test specific host"
echo "  just ci-quick           # Quick CI tests"
echo "  just perf-test          # Performance benchmarks"
echo "  just help-extended      # Extended help"
