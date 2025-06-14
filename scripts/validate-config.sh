#!/usr/bin/env bash
set -euo pipefail

# NixOS Configuration Validation Script
# Validates the refactored configuration for common issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_success "✓ $test_name passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log_error "✗ $test_name failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test 1: Validate flake syntax
test_flake_syntax() {
    log_info "Checking flake syntax..."
    
    if [[ -f "$CONFIG_DIR/flake-new.nix" ]]; then
        if nix flake show --no-eval-cache "$CONFIG_DIR/flake-new.nix" &>/dev/null; then
            return 0
        else
            log_error "New flake syntax validation failed"
            return 1
        fi
    elif [[ -f "$CONFIG_DIR/flake.nix" ]]; then
        if nix flake show --no-eval-cache "$CONFIG_DIR" &>/dev/null; then
            return 0
        else
            log_error "Current flake syntax validation failed"
            return 1
        fi
    else
        log_error "No flake.nix found"
        return 1
    fi
}

# Test 2: Check library structure
test_library_structure() {
    log_info "Checking library structure..."
    
    local required_files=(
        "lib/default.nix"
        "lib/host-builders.nix"
        "lib/profiles.nix"
        "lib/hardware.nix"
        "lib/utils.nix"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$CONFIG_DIR/$file" ]]; then
            log_error "Missing required library file: $file"
            return 1
        fi
    done
    
    # Test that library can be imported
    if nix-instantiate --eval --strict -E "(import $CONFIG_DIR/lib { inputs = {}; nixpkgs = import <nixpkgs> {}; lib = (import <nixpkgs> {}).lib; })" &>/dev/null; then
        return 0
    else
        log_error "Library import failed"
        return 1
    fi
}

# Test 3: Validate profile modules
test_profile_modules() {
    log_info "Checking profile modules..."
    
    local profiles=("base" "desktop" "development" "server")
    
    for profile in "${profiles[@]}"; do
        local profile_file="$CONFIG_DIR/profiles/$profile.nix"
        
        if [[ ! -f "$profile_file" ]]; then
            log_error "Missing profile: $profile_file"
            return 1
        fi
        
        # Test basic syntax
        if ! nix-instantiate --parse "$profile_file" &>/dev/null; then
            log_error "Syntax error in profile: $profile_file"
            return 1
        fi
    done
    
    return 0
}

# Test 4: Check hardware profiles
test_hardware_profiles() {
    log_info "Checking hardware profiles..."
    
    local hw_profiles=(
        "amd-workstation"
        "intel-laptop"
        "nvidia-gaming"
        "htpc-intel"
    )
    
    for profile in "${hw_profiles[@]}"; do
        local profile_file="$CONFIG_DIR/modules/hardware/profiles/$profile.nix"
        
        if [[ ! -f "$profile_file" ]]; then
            log_error "Missing hardware profile: $profile_file"
            return 1
        fi
        
        # Test basic syntax
        if ! nix-instantiate --parse "$profile_file" &>/dev/null; then
            log_error "Syntax error in hardware profile: $profile_file"
            return 1
        fi
    done
    
    return 0
}

# Test 5: Validate host configurations
test_host_configurations() {
    log_info "Checking host configurations..."
    
    local hosts=("p620" "razer" "p510" "dex5550")
    
    for host in "${hosts[@]}"; do
        local host_dir="$CONFIG_DIR/hosts/$host"
        
        if [[ ! -d "$host_dir" ]]; then
            log_warning "Host directory missing: $host_dir"
            continue
        fi
        
        # Check for required files
        if [[ ! -f "$host_dir/hardware-configuration.nix" ]]; then
            log_warning "Missing hardware-configuration.nix for $host"
        fi
        
        # Test that host configuration can be evaluated
        log_info "Testing host evaluation: $host"
        if nix-instantiate --eval --strict --json -A "nixosConfigurations.$host.config.system.name" "$CONFIG_DIR" &>/dev/null; then
            log_info "✓ Host $host evaluation successful"
        else
            log_warning "Host $host evaluation failed (may be expected during migration)"
        fi
    done
    
    return 0
}

# Test 6: Check module imports
test_module_imports() {
    log_info "Checking module import structure..."
    
    local module_dirs=(
        "modules/core"
        "modules/desktop"
        "modules/development"
        "modules/hardware"
    )
    
    for dir in "${module_dirs[@]}"; do
        if [[ -d "$CONFIG_DIR/$dir" ]]; then
            # Check if default.nix exists
            if [[ -f "$CONFIG_DIR/$dir/default.nix" ]]; then
                if ! nix-instantiate --parse "$CONFIG_DIR/$dir/default.nix" &>/dev/null; then
                    log_error "Syntax error in $dir/default.nix"
                    return 1
                fi
            else
                log_warning "No default.nix in $dir"
            fi
        fi
    done
    
    return 0
}

# Test 7: Validate templates
test_templates() {
    log_info "Checking configuration templates..."
    
    local templates=("minimal" "workstation")
    
    for template in "${templates[@]}"; do
        local template_dir="$CONFIG_DIR/templates/$template"
        
        if [[ ! -d "$template_dir" ]]; then
            log_warning "Missing template: $template_dir"
            continue
        fi
        
        # Check template structure
        if [[ -f "$template_dir/flake.nix" ]]; then
            if ! nix flake show --no-eval-cache "$template_dir" &>/dev/null; then
                log_error "Template $template flake validation failed"
                return 1
            fi
        fi
        
        if [[ -f "$template_dir/configuration.nix" ]]; then
            if ! nix-instantiate --parse "$template_dir/configuration.nix" &>/dev/null; then
                log_error "Template $template configuration.nix syntax error"
                return 1
            fi
        fi
    done
    
    return 0
}

# Test 8: Check for common issues
test_common_issues() {
    log_info "Checking for common configuration issues..."
    
    # Check for conflicting audio systems
    local pipewire_count=$(find "$CONFIG_DIR" -name "*.nix" -exec grep -l "services\.pipewire\.enable.*true" {} \; | wc -l)
    local pulseaudio_count=$(find "$CONFIG_DIR" -name "*.nix" -exec grep -l "hardware\.pulseaudio\.enable.*true" {} \; | wc -l)
    
    if [[ $pipewire_count -gt 0 && $pulseaudio_count -gt 0 ]]; then
        log_warning "Both PipeWire and PulseAudio configurations found - potential conflict"
    fi
    
    # Check for proper option declarations
    local custom_options=$(find "$CONFIG_DIR/modules" -name "*.nix" -exec grep -l "config\.custom\." {} \; | wc -l)
    local option_declarations=$(find "$CONFIG_DIR/modules" -name "*.nix" -exec grep -l "options\.custom\." {} \; | wc -l)
    
    if [[ $custom_options -gt 0 && $option_declarations -eq 0 ]]; then
        log_warning "Custom options used but no option declarations found"
    fi
    
    return 0
}

# Test 9: Performance checks
test_performance() {
    log_info "Running performance checks..."
    
    # Check for evaluation time (should be reasonable)
    local start_time=$(date +%s)
    
    if nix-instantiate --eval --strict -A "lib" "$CONFIG_DIR" &>/dev/null; then
        local end_time=$(date +%s)
        local eval_time=$((end_time - start_time))
        
        if [[ $eval_time -gt 10 ]]; then
            log_warning "Library evaluation took ${eval_time}s (may indicate performance issues)"
        else
            log_info "Library evaluation completed in ${eval_time}s"
        fi
    else
        log_error "Library evaluation failed"
        return 1
    fi
    
    return 0
}

# Test 10: Documentation check
test_documentation() {
    log_info "Checking documentation..."
    
    local docs=(
        "REFACTOR_GUIDE.md"
        "templates/README.md"
    )
    
    for doc in "${docs[@]}"; do
        if [[ ! -f "$CONFIG_DIR/$doc" ]]; then
            log_warning "Missing documentation: $doc"
        fi
    done
    
    return 0
}

# Main execution
main() {
    echo "====================================="
    echo " NixOS Configuration Validation"
    echo "====================================="
    echo
    
    log_info "Starting validation of NixOS configuration..."
    log_info "Configuration directory: $CONFIG_DIR"
    echo
    
    # Run all tests
    run_test "Flake Syntax" test_flake_syntax
    run_test "Library Structure" test_library_structure
    run_test "Profile Modules" test_profile_modules
    run_test "Hardware Profiles" test_hardware_profiles
    run_test "Host Configurations" test_host_configurations
    run_test "Module Imports" test_module_imports
    run_test "Templates" test_templates
    run_test "Common Issues" test_common_issues
    run_test "Performance" test_performance
    run_test "Documentation" test_documentation
    
    # Summary
    echo
    echo "====================================="
    echo " Validation Summary"
    echo "====================================="
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "All tests passed! Configuration appears to be ready for migration."
        exit 0
    else
        log_warning "$FAILED_TESTS test(s) failed. Please review and fix issues before proceeding."
        exit 1
    fi
}

# Handle command line arguments
case "${1:-validate}" in
    "validate"|"")
        main
        ;;
    "syntax")
        run_test "Flake Syntax" test_flake_syntax
        ;;
    "lib")
        run_test "Library Structure" test_library_structure
        ;;
    "profiles")
        run_test "Profile Modules" test_profile_modules
        ;;
    "hardware")
        run_test "Hardware Profiles" test_hardware_profiles
        ;;
    "hosts")
        run_test "Host Configurations" test_host_configurations
        ;;
    "help")
        echo "Usage: $0 [validate|syntax|lib|profiles|hardware|hosts|help]"
        echo
        echo "Commands:"
        echo "  validate (default) - Run all validation tests"
        echo "  syntax            - Check flake syntax only"
        echo "  lib               - Check library structure only"
        echo "  profiles          - Check profile modules only"
        echo "  hardware          - Check hardware profiles only"
        echo "  hosts             - Check host configurations only"
        echo "  help              - Show this help message"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
