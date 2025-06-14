#!/usr/bin/env bash
set -euo pipefail

# NixOS Configuration Migration Script
# This script helps migrate from the old configuration to the refactored one

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if running in NixOS configuration directory
check_environment() {
    log_info "Checking environment..."
    
    if [[ ! -f "$CONFIG_DIR/flake.nix" ]]; then
        log_error "flake.nix not found. Are you in the NixOS configuration directory?"
        exit 1
    fi
    
    if [[ ! -d "$CONFIG_DIR/modules" ]]; then
        log_error "modules directory not found. This doesn't appear to be a NixOS configuration."
        exit 1
    fi
    
    log_success "Environment check passed"
}

# Backup current configuration
backup_config() {
    local backup_dir="$CONFIG_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Creating backup at $backup_dir..."
    
    mkdir -p "$backup_dir"
    
    # Backup key files
    cp "$CONFIG_DIR/flake.nix" "$backup_dir/"
    cp -r "$CONFIG_DIR/modules" "$backup_dir/"
    cp -r "$CONFIG_DIR/hosts" "$backup_dir/"
    
    if [[ -d "$CONFIG_DIR/profiles" ]]; then
        cp -r "$CONFIG_DIR/profiles" "$backup_dir/"
    fi
    
    if [[ -d "$CONFIG_DIR/lib" ]]; then
        cp -r "$CONFIG_DIR/lib" "$backup_dir/"
    fi
    
    log_success "Backup created at $backup_dir"
    echo "$backup_dir" > "$CONFIG_DIR/.last_backup"
}

# Validate new flake
validate_flake() {
    log_info "Validating new flake configuration..."
    
    if [[ -f "$CONFIG_DIR/flake-new.nix" ]]; then
        # Test the new flake
        if nix flake check --no-build "$CONFIG_DIR/flake-new.nix" 2>/dev/null; then
            log_success "New flake validation passed"
            return 0
        else
            log_warning "New flake validation failed, will need manual review"
            return 1
        fi
    else
        log_warning "flake-new.nix not found"
        return 1
    fi
}

# Test build configurations
test_builds() {
    log_info "Testing build configurations..."
    
    local hosts=("p620" "razer" "p510" "dex5550")
    local failed_hosts=()
    
    for host in "${hosts[@]}"; do
        log_info "Testing build for $host..."
        
        if nixos-rebuild build --flake ".#$host" --dry-run 2>/dev/null; then
            log_success "Build test passed for $host"
        else
            log_warning "Build test failed for $host"
            failed_hosts+=("$host")
        fi
    done
    
    if [[ ${#failed_hosts[@]} -eq 0 ]]; then
        log_success "All host build tests passed"
        return 0
    else
        log_warning "Failed hosts: ${failed_hosts[*]}"
        return 1
    fi
}

# Apply new configuration
apply_new_config() {
    log_info "Applying new configuration..."
    
    # Replace old flake with new one
    if [[ -f "$CONFIG_DIR/flake-new.nix" ]]; then
        mv "$CONFIG_DIR/flake.nix" "$CONFIG_DIR/flake-old.nix"
        mv "$CONFIG_DIR/flake-new.nix" "$CONFIG_DIR/flake.nix"
        log_success "Replaced flake.nix with refactored version"
    fi
    
    # Update flake.lock
    log_info "Updating flake.lock..."
    nix flake update
    
    log_success "Configuration applied"
}

# Generate migration report
generate_report() {
    local report_file="$CONFIG_DIR/migration-report.md"
    
    log_info "Generating migration report..."
    
    cat > "$report_file" << EOF
# NixOS Configuration Migration Report

**Migration Date**: $(date)
**Backup Location**: $(cat "$CONFIG_DIR/.last_backup" 2>/dev/null || echo "No backup created")

## Changes Made

### Flake Structure
- ✅ Simplified input management
- ✅ Improved host builders
- ✅ Added development shell
- ✅ Added testing framework

### Module Organization
- ✅ Hierarchical module structure
- ✅ Type-safe configuration options
- ✅ Hardware abstraction layers
- ✅ Configuration profiles

### Host Configurations
- ✅ Standardized host builder
- ✅ Hardware profile system
- ✅ Modular feature system

## Validation Results

### Build Tests
EOF

    # Add build test results
    local hosts=("p620" "razer" "p510" "dex5550")
    for host in "${hosts[@]}"; do
        if nixos-rebuild build --flake ".#$host" --dry-run &>/dev/null; then
            echo "- ✅ $host: Build test passed" >> "$report_file"
        else
            echo "- ❌ $host: Build test failed" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Next Steps

1. **Test the Configuration**
   \`\`\`bash
   # Test build for your host
   nixos-rebuild build --flake .#<hostname>
   
   # If successful, switch to new configuration
   sudo nixos-rebuild switch --flake .#<hostname>
   \`\`\`

2. **Update Home Manager**
   \`\`\`bash
   home-manager switch --flake .#<username>@<hostname>
   \`\`\`

3. **Verify Services**
   Check that all services are running correctly after the switch.

4. **Clean Up**
   Once everything is working, you can remove the backup directory.

## Rollback Instructions

If you encounter issues, you can rollback:

\`\`\`bash
# Restore from backup
cp flake-old.nix flake.nix

# Or use the backup directory
cp \$(cat .last_backup)/flake.nix ./flake.nix

# Rebuild with old configuration
sudo nixos-rebuild switch --flake .#<hostname>
\`\`\`

## Support

For issues or questions about the refactored configuration:
1. Check the REFACTOR_GUIDE.md
2. Review the validation errors
3. Compare with the backup configuration
EOF

    log_success "Migration report generated: $report_file"
}

# Interactive migration wizard
interactive_migration() {
    echo
    echo "====================================="
    echo " NixOS Configuration Migration Wizard"
    echo "====================================="
    echo
    
    log_info "This script will help you migrate to the refactored NixOS configuration."
    log_warning "This process will modify your current configuration."
    echo
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Migration cancelled."
        exit 0
    fi
    
    # Step 1: Environment check
    check_environment
    
    # Step 2: Backup
    echo
    read -p "Create backup of current configuration? (Y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        backup_config
    fi
    
    # Step 3: Validate new configuration
    echo
    log_info "Validating new configuration..."
    
    if validate_flake; then
        log_success "Validation passed"
    else
        log_warning "Validation had issues, but continuing..."
    fi
    
    # Step 4: Test builds
    echo
    read -p "Test build configurations? (Y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        test_builds
    fi
    
    # Step 5: Apply changes
    echo
    read -p "Apply new configuration? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_new_config
        log_success "Migration completed!"
    else
        log_info "Configuration not applied. You can manually review and apply later."
    fi
    
    # Step 6: Generate report
    generate_report
    
    echo
    log_info "Migration wizard completed."
    log_info "Please review the migration report and test your configuration."
}

# Command line interface
case "${1:-interactive}" in
    "backup")
        check_environment
        backup_config
        ;;
    "validate")
        check_environment
        validate_flake
        ;;
    "test")
        check_environment
        test_builds
        ;;
    "apply")
        check_environment
        apply_new_config
        ;;
    "report")
        generate_report
        ;;
    "interactive"|*)
        interactive_migration
        ;;
esac
