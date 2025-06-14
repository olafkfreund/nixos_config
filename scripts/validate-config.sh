#!/usr/bin/env bash

# NixOS Configuration Validation Script
# Comprehensive testing and validation for the flake configuration

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
ACTIVE_HOSTS=("razer" "dex5550" "p510" "p620")
ARCHIVED_HOSTS=("hp" "lms" "pvm")
TEST_TIMEOUT=300 # 5 minutes

# Logging
LOG_FILE="/tmp/nixos-validation-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}${BOLD}ERROR:${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} $*" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}${BOLD}WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}${BOLD}INFO:${NC} $*" | tee -a "$LOG_FILE"
}

# Check dependencies
check_dependencies() {
    local deps=("nix" "nixos-rebuild" "agenix" "jq" "timeout")
    local missing=()
    
    info "Checking dependencies..."
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    success "All dependencies available"
    return 0
}

# Validate flake structure
validate_flake_structure() {
    info "Validating flake structure..."
    
    local required_files=("flake.nix" "flake.lock")
    local required_dirs=("hosts" "modules" "home" "Users")
    
    cd "$CONFIG_DIR"
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Missing required file: $file"
            return 1
        fi
    done
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            error "Missing required directory: $dir"
            return 1
        fi
    done
    
    success "Flake structure validation passed"
    return 0
}

# Test flake check
test_flake_check() {
    info "Running nix flake check..."
    
    cd "$CONFIG_DIR"
    
    if timeout "$TEST_TIMEOUT" nix flake check --show-trace 2>&1 | tee -a "$LOG_FILE"; then
        success "Flake check passed"
        return 0
    else
        error "Flake check failed"
        return 1
    fi
}

# Test host configuration builds
test_host_builds() {
    local host="$1"
    local timeout_duration="${2:-$TEST_TIMEOUT}"
    
    info "Testing build for host: $host"
    
    cd "$CONFIG_DIR"
    
    if timeout "$timeout_duration" nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --show-trace 2>&1 | tee -a "$LOG_FILE"; then
        success "Host $host builds successfully"
        return 0
    else
        error "Host $host build failed"
        return 1
    fi
}

# Test all active hosts
test_all_hosts() {
    info "Testing all active host configurations..."
    
    local failed_hosts=()
    
    for host in "${ACTIVE_HOSTS[@]}"; do
        if ! test_host_builds "$host"; then
            failed_hosts+=("$host")
        fi
    done
    
    if [ ${#failed_hosts[@]} -eq 0 ]; then
        success "All active hosts build successfully"
        return 0
    else
        error "Failed hosts: ${failed_hosts[*]}"
        return 1
    fi
}

# Test Home Manager configurations
test_home_manager() {
    info "Testing Home Manager configurations..."
    
    local failed_configs=()
    
    for host in "${ACTIVE_HOSTS[@]}"; do
        info "Testing Home Manager integration for $host"
        
        cd "$CONFIG_DIR"
        
        # Test if the home-manager options are available in the NixOS config
        if timeout "$TEST_TIMEOUT" nix eval ".#nixosConfigurations.$host.options.home-manager" --json > /dev/null 2>&1; then
            success "Home Manager integration for $host is valid"
        else
            warning "Home Manager integration for $host failed"
            failed_configs+=("$host")
        fi
    done
    
    if [ ${#failed_configs[@]} -eq 0 ]; then
        success "All Home Manager integrations are valid"
        return 0
    else
        warning "Failed Home Manager integrations: ${failed_configs[*]}"
        return 1
    fi
}

# Test secrets
test_secrets() {
    info "Testing secrets decryption..."
    
    cd "$CONFIG_DIR"
    
    local secret_files=(secrets/*.age)
    local failed_secrets=()
    
    if [ ! -e "${secret_files[0]}" ]; then
        warning "No secret files found to test"
        return 0
    fi
    
    for secret_file in "${secret_files[@]}"; do
        if [[ -f "$secret_file" ]]; then
            info "Testing decryption of $(basename "$secret_file")"
            if agenix -d "$secret_file" > /dev/null 2>&1; then
                success "Secret $(basename "$secret_file") decrypts successfully"
            else
                error "Secret $(basename "$secret_file") failed to decrypt"
                failed_secrets+=("$(basename "$secret_file")")
            fi
        fi
    done
    
    if [ ${#failed_secrets[@]} -eq 0 ]; then
        success "All secrets decrypt successfully"
        return 0
    else
        error "Failed secrets: ${failed_secrets[*]}"
        return 1
    fi
}

# Test host connectivity
test_host_connectivity() {
    info "Testing host connectivity..."
    
    local unreachable_hosts=()
    
    for host in "${ACTIVE_HOSTS[@]}"; do
        info "Pinging $host..."
        if ping -c 1 -W 2 "$host" > /dev/null 2>&1; then
            success "Host $host is reachable"
        else
            warning "Host $host is unreachable"
            unreachable_hosts+=("$host")
        fi
    done
    
    if [ ${#unreachable_hosts[@]} -eq 0 ]; then
        success "All hosts are reachable"
        return 0
    else
        warning "Unreachable hosts: ${unreachable_hosts[*]}"
        return 1
    fi
}

# Test syntax of key configuration files
test_syntax() {
    info "Testing Nix file syntax..."
    
    local syntax_errors=()
    
    cd "$CONFIG_DIR"
    
    # Find all .nix files excluding result directories and .git
    while IFS= read -r -d '' file; do
        if nix-instantiate --parse "$file" > /dev/null 2>&1; then
            continue
        else
            error "Syntax error in $file"
            syntax_errors+=("$file")
        fi
    done < <(find . -name "*.nix" -not -path "./result*" -not -path "./.git/*" -print0)
    
    if [ ${#syntax_errors[@]} -eq 0 ]; then
        success "All Nix files have valid syntax"
        return 0
    else
        error "Files with syntax errors: ${syntax_errors[*]}"
        return 1
    fi
}

# Test package availability
test_packages() {
    info "Testing custom package builds..."
    
    cd "$CONFIG_DIR"
    
    local packages_output
    if packages_output=$(nix flake show --json 2>/dev/null | jq -r '.packages."x86_64-linux" | keys[]' 2>/dev/null); then
        if [[ -n "$packages_output" ]]; then
            echo "$packages_output" | while read -r package; do
                info "Testing package: $package"
                if timeout 60 nix build ".#$package" --show-trace 2>&1 | tee -a "$LOG_FILE"; then
                    success "Package $package builds successfully"
                else
                    warning "Package $package failed to build"
                fi
            done
        else
            info "No custom packages found to test"
        fi
    else
        warning "Could not enumerate packages for testing"
    fi
}

# Generate validation report
generate_report() {
    local start_time="$1"
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo -e "\n${PURPLE}${BOLD}=== VALIDATION REPORT ===${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Started:${NC} $(date -d "@$start_time" '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Finished:${NC} $(date -d "@$end_time" '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Duration:${NC} ${duration}s" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Log file:${NC} $LOG_FILE" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Active hosts:${NC} ${ACTIVE_HOSTS[*]}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}Archived hosts:${NC} ${ARCHIVED_HOSTS[*]}" | tee -a "$LOG_FILE"
}

# Main validation function
main() {
    local start_time
    start_time=$(date +%s)
    
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         NixOS Configuration Validator                        ║"
    echo "║                                                                              ║"
    echo "║  This script performs comprehensive testing of your NixOS configuration     ║"
    echo "║  including flake validation, host builds, and secrets testing.             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    info "Starting validation process..."
    info "Configuration directory: $CONFIG_DIR"
    info "Log file: $LOG_FILE"
    
    local tests=(
        "check_dependencies"
        "validate_flake_structure" 
        "test_flake_check"
        "test_syntax"
        "test_all_hosts"
        "test_home_manager"
        "test_secrets"
        "test_packages"
        "test_host_connectivity"
    )
    
    local failed_tests=()
    local passed_tests=()
    
    for test in "${tests[@]}"; do
        echo -e "\n${CYAN}${BOLD}Running: $test${NC}"
        if "$test"; then
            passed_tests+=("$test")
        else
            failed_tests+=("$test")
        fi
    done
    
    # Generate final report
    echo -e "\n${PURPLE}${BOLD}=== SUMMARY ===${NC}"
    echo -e "${GREEN}Passed tests (${#passed_tests[@]}):${NC} ${passed_tests[*]}"
    
    if [ ${#failed_tests[@]} -gt 0 ]; then
        echo -e "${RED}Failed tests (${#failed_tests[@]}):${NC} ${failed_tests[*]}"
        echo -e "\n${RED}${BOLD}Validation completed with errors${NC}"
        generate_report "$start_time"
        exit 1
    else
        echo -e "\n${GREEN}${BOLD}✅ All validation tests passed!${NC}"
        generate_report "$start_time"
        exit 0
    fi
}

# Help function
show_help() {
    echo "NixOS Configuration Validator"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -t, --timeout  Set timeout for tests (default: $TEST_TIMEOUT seconds)"
    echo "  -q, --quick    Run quick validation (skip time-consuming tests)"
    echo "  -v, --verbose  Enable verbose output"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run full validation"
    echo "  $0 --quick           # Run quick validation"
    echo "  $0 --timeout 600     # Set 10-minute timeout"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        -q|--quick)
            # Remove time-consuming tests for quick mode
            ACTIVE_HOSTS=("razer") # Test only one host
            shift
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
