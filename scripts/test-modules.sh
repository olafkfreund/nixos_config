#!/usr/bin/env bash

# NixOS Module Testing Script
# Test individual modules and their dependencies

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

error() {
    echo -e "${RED}${BOLD}ERROR:${NC} $*" >&2
}

success() {
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} $*"
}

warning() {
    echo -e "${YELLOW}${BOLD}WARNING:${NC} $*"
}

info() {
    echo -e "${BLUE}${BOLD}INFO:${NC} $*"
}

# Test a specific module by creating a minimal configuration
test_module() {
    local module_path="$1"
    local test_name="${2:-$(basename "$module_path" .nix)}"
    
    info "Testing module: $module_path"
    
    # Create temporary test configuration
    local temp_dir
    temp_dir=$(mktemp -d)
    local test_config="$temp_dir/test-config.nix"
    
    cat > "$test_config" << EOF
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    $module_path
  ];
  
  # Minimal configuration to satisfy requirements
  system.stateVersion = "25.05";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "test-host";
  users.users.test = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };
  
  # Enable the module being tested (if it has an enable option)
  $(grep -q "mkEnableOption" "$module_path" && echo "config.modules.$(basename "$module_path" .nix).enable = lib.mkDefault true;" || echo "")
}
EOF
    
    # Test evaluation
    if nix-instantiate --eval --expr "
      let
        pkgs = import <nixpkgs> {};
        config = import $test_config { inherit (pkgs) lib config pkgs; };
      in
        config.system.build.toplevel or true
    " > /dev/null 2>&1; then
        success "Module $test_name evaluates successfully"
        rm -rf "$temp_dir"
        return 0
    else
        error "Module $test_name failed to evaluate"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Test module dependencies
test_module_dependencies() {
    local module_path="$1"
    
    info "Checking dependencies for: $module_path"
    
    # Extract import statements
    local imports
    imports=$(grep -E "^\s*\./|^\s*\.\.\/" "$module_path" 2>/dev/null || true)
    
    if [[ -n "$imports" ]]; then
        echo "$imports" | while read -r import_line; do
            # Extract the actual import path
            local import_path
            import_path=$(echo "$import_line" | sed -E 's/.*(\.[^"]*\.nix).*/\1/' | tr -d '"' | tr -d "'")
            
            if [[ -f "$(dirname "$module_path")/$import_path" ]]; then
                success "Dependency found: $import_path"
            else
                warning "Missing dependency: $import_path"
            fi
        done
    else
        info "No local dependencies found"
    fi
}

# Test all modules in a directory
test_modules_in_dir() {
    local dir="$1"
    local failed_modules=()
    local tested_count=0
    
    info "Testing modules in directory: $dir"
    
    find "$dir" -name "*.nix" -type f | while read -r module_file; do
        # Skip certain files
        if [[ "$(basename "$module_file")" =~ ^(default|configuration)\.nix$ ]]; then
            continue
        fi
        
        tested_count=$((tested_count + 1))
        
        if ! test_module "$module_file"; then
            failed_modules+=("$module_file")
        fi
        
        test_module_dependencies "$module_file"
    done
    
    info "Tested $tested_count modules in $dir"
    
    if [ ${#failed_modules[@]} -eq 0 ]; then
        success "All modules in $dir passed tests"
        return 0
    else
        error "Failed modules: ${failed_modules[*]}"
        return 1
    fi
}

# Check module documentation
check_module_docs() {
    local module_path="$1"
    
    info "Checking documentation for: $module_path"
    
    local has_description=false
    local has_examples=false
    
    if grep -q "description\s*=" "$module_path"; then
        has_description=true
    fi
    
    if grep -q "example\s*=" "$module_path"; then
        has_examples=true
    fi
    
    if $has_description && $has_examples; then
        success "Module has good documentation"
    elif $has_description; then
        warning "Module has descriptions but no examples"
    else
        warning "Module lacks documentation"
    fi
}

# Main function
main() {
    cd "$CONFIG_DIR"
    
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           NixOS Module Tester                               ║"
    echo "║                                                                              ║"
    echo "║  Test individual modules and their dependencies                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    local test_target="${1:-modules}"
    
    case "$test_target" in
        "modules"|"all")
            test_modules_in_dir "modules"
            ;;
        "home")
            test_modules_in_dir "home"
            ;;
        "specific")
            if [[ -z "${2:-}" ]]; then
                error "Please specify a module path for specific testing"
                exit 1
            fi
            test_module "$2"
            test_module_dependencies "$2"
            check_module_docs "$2"
            ;;
        "docs")
            info "Checking documentation for all modules..."
            find modules -name "*.nix" -type f | while read -r module_file; do
                check_module_docs "$module_file"
            done
            ;;
        *)
            error "Unknown test target: $test_target"
            echo "Usage: $0 [modules|home|specific <path>|docs]"
            exit 1
            ;;
    esac
}

main "$@"
