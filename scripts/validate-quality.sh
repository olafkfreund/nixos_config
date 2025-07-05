#!/usr/bin/env bash

# NixOS Configuration Quality Validation Script
# Additional quality checks for documentation, patterns, and best practices

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
QUALITY_LOG="/tmp/nixos-quality-validation-$(date +%Y%m%d-%H%M%S).log"

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" | tee -a "$QUALITY_LOG"
}

error() {
    echo -e "${RED}${BOLD}ERROR:${NC} $*" | tee -a "$QUALITY_LOG"
}

success() {
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} $*" | tee -a "$QUALITY_LOG"
}

warning() {
    echo -e "${YELLOW}${BOLD}WARNING:${NC} $*" | tee -a "$QUALITY_LOG"
}

info() {
    echo -e "${BLUE}${BOLD}INFO:${NC} $*" | tee -a "$QUALITY_LOG"
}

quality() {
    echo -e "${PURPLE}${BOLD}QUALITY:${NC} $*" | tee -a "$QUALITY_LOG"
}

# Header
show_header() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    NixOS Configuration Quality Validator                    ║"
    echo "║                                                                              ║"
    echo "║  This script performs quality checks for documentation, patterns,           ║"
    echo "║  and best practices across the NixOS configuration.                        ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check module documentation quality
check_module_documentation() {
    info "Checking module documentation quality..."
    
    local modules_dir="$CONFIG_DIR/modules"
    local total_modules=0
    local documented_modules=0
    local well_documented_modules=0
    local issues=()
    
    cd "$modules_dir"
    
    # Find all .nix files in modules directory
    while IFS= read -r -d '' module_file; do
        ((total_modules++))
        local relative_path="${module_file#$modules_dir/}"
        
        # Skip template files
        if [[ "$relative_path" == *"TEMPLATE"* ]] || [[ "$relative_path" == *"template"* ]]; then
            continue
        fi
        
        local has_options=false
        local has_descriptions=false
        local has_examples=false
        local has_enable_option=false
        local has_meta=false
        
        # Check for basic module structure
        if grep -q "options\." "$module_file"; then
            has_options=true
            ((documented_modules++))
        fi
        
        # Check for option descriptions
        if grep -q "description\s*=" "$module_file"; then
            has_descriptions=true
        fi
        
        # Check for examples
        if grep -q "example\s*=" "$module_file"; then
            has_examples=true
        fi
        
        # Check for enable option
        if grep -q "mkEnableOption\|enable.*mkOption" "$module_file"; then
            has_enable_option=true
        fi
        
        # Check for meta information
        if grep -q "meta\s*=" "$module_file"; then
            has_meta=true
        fi
        
        # Determine documentation quality
        local quality_score=0
        $has_options && ((quality_score++))
        $has_descriptions && ((quality_score++))
        $has_examples && ((quality_score++))
        $has_enable_option && ((quality_score++))
        $has_meta && ((quality_score++))
        
        if [ $quality_score -ge 4 ]; then
            ((well_documented_modules++))
        elif [ $quality_score -eq 0 ]; then
            issues+=("$relative_path: No documentation structure found")
        elif [ ! $has_enable_option ]; then
            issues+=("$relative_path: Missing enable option")
        elif [ ! $has_descriptions ]; then
            issues+=("$relative_path: Missing option descriptions")
        fi
        
    done < <(find . -name "*.nix" -type f -print0)
    
    # Report results
    quality "Module Documentation Analysis:"
    quality "  Total modules: $total_modules"
    quality "  Modules with options: $documented_modules"
    quality "  Well-documented modules: $well_documented_modules"
    quality "  Documentation coverage: $((documented_modules * 100 / total_modules))%"
    quality "  High-quality documentation: $((well_documented_modules * 100 / total_modules))%"
    
    if [ ${#issues[@]} -gt 0 ]; then
        warning "Documentation issues found:"
        printf '%s\n' "${issues[@]}" | while read -r issue; do
            warning "  $issue"
        done
    fi
    
    return 0
}

# Check for consistent option naming patterns
check_option_patterns() {
    info "Checking option naming patterns..."
    
    local modules_dir="$CONFIG_DIR/modules"
    local inconsistencies=()
    
    cd "$modules_dir"
    
    # Check for inconsistent option prefixes
    local option_patterns=(
        "config\.modules\."
        "config\.services\."
        "config\.programs\."
        "config\.[a-z]+\."
    )
    
    while IFS= read -r -d '' module_file; do
        local relative_path="${module_file#$modules_dir/}"
        
        # Skip template files
        if [[ "$relative_path" == *"TEMPLATE"* ]]; then
            continue
        fi
        
        # Check for different option patterns in same file
        local found_patterns=()
        for pattern in "${option_patterns[@]}"; do
            if grep -q "$pattern" "$module_file"; then
                found_patterns+=("$pattern")
            fi
        done
        
        # If multiple patterns found, it might be inconsistent
        if [ ${#found_patterns[@]} -gt 1 ]; then
            inconsistencies+=("$relative_path: Multiple option patterns: ${found_patterns[*]}")
        fi
        
        # Check for missing 'modules.' prefix in options
        if grep -q "options\." "$module_file" && ! grep -q "options\.modules\." "$module_file" && ! grep -q "options\.services\." "$module_file"; then
            if ! grep -q "# Legacy module" "$module_file"; then
                inconsistencies+=("$relative_path: Consider using 'modules.' prefix for consistency")
            fi
        fi
        
    done < <(find . -name "*.nix" -type f -print0)
    
    if [ ${#inconsistencies[@]} -eq 0 ]; then
        success "Option naming patterns are consistent"
    else
        warning "Option pattern inconsistencies found:"
        printf '%s\n' "${inconsistencies[@]}" | while read -r issue; do
            warning "  $issue"
        done
    fi
    
    return 0
}

# Check for code quality issues
check_code_quality() {
    info "Checking code quality..."
    
    local quality_issues=()
    local modules_dir="$CONFIG_DIR/modules"
    
    cd "$modules_dir"
    
    # Check for common quality issues
    while IFS= read -r -d '' module_file; do
        local relative_path="${module_file#$modules_dir/}"
        
        # Skip template files
        if [[ "$relative_path" == *"TEMPLATE"* ]]; then
            continue
        fi
        
        # Check for TODO/FIXME comments
        if grep -n "TODO\|FIXME\|XXX\|HACK" "$module_file"; then
            quality_issues+=("$relative_path: Contains TODO/FIXME comments")
        fi
        
        # Check for commented out code blocks
        local commented_lines=$(grep -c "^\s*#[^#]" "$module_file" || true)
        local total_lines=$(wc -l < "$module_file")
        if [ $commented_lines -gt $((total_lines / 4)) ]; then
            quality_issues+=("$relative_path: High ratio of commented code ($commented_lines/$total_lines lines)")
        fi
        
        # Check for hardcoded paths
        if grep -q '"/home/\|"/root/\|"/tmp/' "$module_file"; then
            quality_issues+=("$relative_path: Contains hardcoded paths")
        fi
        
        # Check for missing assertions in complex modules
        if grep -q "mkIf.*enable" "$module_file" && ! grep -q "assertions\s*=" "$module_file" && [ "$(wc -l < "$module_file")" -gt 50 ]; then
            quality_issues+=("$relative_path: Complex module missing assertions")
        fi
        
    done < <(find . -name "*.nix" -type f -print0)
    
    if [ ${#quality_issues[@]} -eq 0 ]; then
        success "No major code quality issues found"
    else
        warning "Code quality issues found:"
        printf '%s\n' "${quality_issues[@]}" | while read -r issue; do
            warning "  $issue"
        done
    fi
    
    return 0
}

# Check for missing README files
check_documentation_coverage() {
    info "Checking documentation coverage..."
    
    local modules_dir="$CONFIG_DIR/modules"
    local missing_docs=()
    
    cd "$modules_dir"
    
    # Check for module directories without README files
    while IFS= read -r -d '' dir; do
        local relative_path="${dir#$modules_dir/}"
        
        # Skip root directory
        if [ "$relative_path" = "." ]; then
            continue
        fi
        
        # Check if directory has complex modules (more than simple package lists)
        local has_complex_modules=false
        while IFS= read -r -d '' module_file; do
            if [ "$(wc -l < "$module_file")" -gt 30 ] && grep -q "options\|config\s*=" "$module_file"; then
                has_complex_modules=true
                break
            fi
        done < <(find "$dir" -maxdepth 1 -name "*.nix" -type f -print0)
        
        # Check for README file
        if $has_complex_modules && ! find "$dir" -maxdepth 1 -name "README*" -type f | grep -q .; then
            missing_docs+=("$relative_path: Complex module directory missing README")
        fi
        
    done < <(find . -type d -print0)
    
    if [ ${#missing_docs[@]} -eq 0 ]; then
        success "Documentation coverage is good"
    else
        warning "Missing documentation:"
        printf '%s\n' "${missing_docs[@]}" | while read -r issue; do
            warning "  $issue"
        done
    fi
    
    return 0
}

# Validate configuration patterns
check_configuration_patterns() {
    info "Checking configuration patterns..."
    
    local pattern_issues=()
    local modules_dir="$CONFIG_DIR/modules"
    
    cd "$modules_dir"
    
    # Check for consistent error handling patterns
    while IFS= read -r -d '' module_file; do
        local relative_path="${module_file#$modules_dir/}"
        
        # Skip template files
        if [[ "$relative_path" == *"TEMPLATE"* ]]; then
            continue
        fi
        
        # Check for modules with enable option but no config
        if grep -q "mkEnableOption" "$module_file" && ! grep -q "config\s*=.*mkIf" "$module_file"; then
            pattern_issues+=("$relative_path: Has enable option but missing conditional config")
        fi
        
        # Check for proper use of mkDefault
        if grep -q "mkDefault" "$module_file" && ! grep -q "lib\.mkDefault\|with lib.*mkDefault" "$module_file"; then
            pattern_issues+=("$relative_path: Using mkDefault without proper lib import")
        fi
        
        # Check for proper package handling
        if grep -q "environment\.systemPackages" "$module_file" && ! grep -q "with pkgs" "$module_file" && ! grep -q "pkgs\." "$module_file"; then
            pattern_issues+=("$relative_path: Installing packages without clear package reference")
        fi
        
    done < <(find . -name "*.nix" -type f -print0)
    
    if [ ${#pattern_issues[@]} -eq 0 ]; then
        success "Configuration patterns are consistent"
    else
        warning "Configuration pattern issues:"
        printf '%s\n' "${pattern_issues[@]}" | while read -r issue; do
            warning "  $issue"
        done
    fi
    
    return 0
}

# Generate quality report
generate_quality_report() {
    info "Generating quality report..."
    
    local report_file="$CONFIG_DIR/quality-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# NixOS Configuration Quality Report

Generated on: $(date)

## Summary

This report provides an overview of the configuration quality, including documentation coverage, code patterns, and best practices adherence.

## Quality Metrics

See detailed analysis in the quality validation log: $QUALITY_LOG

## Recommendations

### High Priority
- Address modules with missing enable options
- Add documentation to complex modules without README files
- Fix configuration pattern inconsistencies

### Medium Priority  
- Standardize option naming patterns
- Improve documentation coverage for all modules
- Add assertions to complex modules

### Low Priority
- Clean up commented code blocks
- Add examples to all option definitions
- Enhance meta information in module headers

## Next Steps

1. Use the module template (modules/TEMPLATE.nix) for new modules
2. Follow the documentation template (modules/MODULE_README_TEMPLATE.md) for new documentation
3. Regular quality validation with this script

EOF

    success "Quality report generated: $report_file"
}

# Main execution
main() {
    show_header
    
    info "Starting quality validation process..."
    info "Configuration directory: $CONFIG_DIR"
    info "Quality log file: $QUALITY_LOG"
    
    echo ""
    
    # Run quality checks
    local checks=(
        "check_module_documentation"
        "check_option_patterns"
        "check_code_quality"
        "check_documentation_coverage"
        "check_configuration_patterns"
    )
    
    local passed_checks=()
    local failed_checks=()
    
    for check in "${checks[@]}"; do
        echo -e "${CYAN}${BOLD}Running: $check${NC}"
        if $check; then
            passed_checks+=("$check")
        else
            failed_checks+=("$check")
        fi
        echo ""
    done
    
    # Generate report
    generate_quality_report
    
    # Summary
    echo -e "${PURPLE}${BOLD}=== QUALITY VALIDATION SUMMARY ===${NC}"
    echo -e "${GREEN}Passed checks (${#passed_checks[@]}):${NC} ${passed_checks[*]}"
    if [ ${#failed_checks[@]} -gt 0 ]; then
        echo -e "${RED}Failed checks (${#failed_checks[@]}):${NC} ${failed_checks[*]}"
    fi
    
    echo ""
    echo -e "${PURPLE}${BOLD}=== QUALITY VALIDATION REPORT ===${NC}"
    echo -e "${CYAN}Started:${NC} $(head -1 "$QUALITY_LOG" | cut -d':' -f1-3)"
    echo -e "${CYAN}Finished:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}Log file:${NC} $QUALITY_LOG"
    
    if [ ${#failed_checks[@]} -eq 0 ]; then
        echo -e "${GREEN}${BOLD}Quality validation completed successfully${NC}"
        return 0
    else
        echo -e "${YELLOW}${BOLD}Quality validation completed with warnings${NC}"
        return 1
    fi
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help]"
        echo "Performs quality validation on NixOS configuration"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac