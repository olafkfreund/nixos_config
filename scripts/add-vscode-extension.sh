#!/usr/bin/env bash
# Script to help add VS Code extensions to your NixOS configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <extension-id>"
    echo "Example: $0 rust-lang.rust-analyzer"
    echo "         $0 ms-python.python"
    echo ""
    echo "This script will:"
    echo "1. Check if the extension exists in nixpkgs"
    echo "2. Show you how to add it to your vscode.nix"
    echo "3. Optionally add it for you"
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

EXTENSION_ID="$1"
PUBLISHER=$(echo "$EXTENSION_ID" | cut -d'.' -f1)
NAME=$(echo "$EXTENSION_ID" | cut -d'.' -f2)

echo -e "${BLUE}🔍 Searching for extension: ${EXTENSION_ID}${NC}"
echo

# Check if extension exists in nixpkgs
if nix search nixpkgs "vscode-extensions.${EXTENSION_ID}" &>/dev/null; then
    echo -e "${GREEN}✅ Extension found in nixpkgs!${NC}"
    echo
    
    # Get extension info
    RESULT=$(nix search nixpkgs "vscode-extensions.${EXTENSION_ID}" 2>/dev/null)
    echo -e "${BLUE}Extension information:${NC}"
    echo "$RESULT"
    echo
    
    echo -e "${YELLOW}📝 To add this extension to your vscode.nix:${NC}"
    echo
    echo "1. Edit home/development/vscode.nix"
    echo "2. Add this line to the extensions list:"
    echo "   vscode-extensions.${EXTENSION_ID}"
    echo
    echo "3. Rebuild your system:"
    echo "   cd /home/olafkfreund/.config/nixos"
    echo "   sudo nixos-rebuild switch --flake ."
    echo
    
    read -p "Would you like me to add this extension automatically? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Add the extension to vscode.nix
        VSCODE_FILE="/home/olafkfreund/.config/nixos/home/development/vscode.nix"
        
        # Find the last extension line and add after it
        if grep -q "vscode-extensions.${EXTENSION_ID}" "$VSCODE_FILE"; then
            echo -e "${YELLOW}⚠️  Extension already exists in configuration${NC}"
        else
            # Add the extension (this is a simple approach)
            echo -e "${GREEN}📝 Adding extension to configuration...${NC}"
            
            # Create a backup
            cp "$VSCODE_FILE" "$VSCODE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Add the extension before the custom extensions line
            sed -i "/# Additional useful extensions/a\\            vscode-extensions.${EXTENSION_ID}     # ${NAME}" "$VSCODE_FILE"
            
            echo -e "${GREEN}✅ Extension added successfully!${NC}"
            echo "Now run: cd /home/olafkfreund/.config/nixos && sudo nixos-rebuild switch --flake ."
        fi
    fi
    
else
    echo -e "${RED}❌ Extension not found in nixpkgs${NC}"
    echo
    echo -e "${YELLOW}🛠️  You'll need to build it from the marketplace:${NC}"
    echo
    echo "1. Get extension details from: https://marketplace.visualstudio.com/items?itemName=${EXTENSION_ID}"
    echo "2. Get the SHA256 hash using: scripts/get-extension-hashes.sh"
    echo "3. Add to customExtensions in vscode.nix:"
    echo
    echo "(pkgs.vscode-utils.buildVscodeMarketplaceExtension {"
    echo "  mktplcRef = {"
    echo "    name = \"${NAME}\";"
    echo "    publisher = \"${PUBLISHER}\";"
    echo "    version = \"VERSION\";"
    echo "    sha256 = \"HASH\";"
    echo "  };"
    echo "  meta = {"
    echo "    description = \"Extension description\";"
    echo "    license = lib.licenses.unfree;"
    echo "  };"
    echo "})"
    echo
    echo "See docs/VSCODE_EXTENSIONS.md for detailed instructions"
fi
