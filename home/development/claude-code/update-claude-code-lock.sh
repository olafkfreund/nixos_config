#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Script directory - where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX_FILE="$SCRIPT_DIR/default.nix"

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in curl jq nix npm sed; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them and try again."
        exit 1
    fi
}

# Get the latest version from npm registry
get_latest_version() {
    local latest_version
    latest_version=$(curl -s "https://registry.npmjs.org/@anthropic-ai/claude-code" | jq -r '.["dist-tags"].latest')
    
    if [ "$latest_version" = "null" ] || [ -z "$latest_version" ]; then
        log_error "Failed to fetch latest version from npm registry" >&2
        exit 1
    fi
    
    echo "$latest_version"
}

# Get current version from default.nix
get_current_version() {
    if [ ! -f "$DEFAULT_NIX_FILE" ]; then
        log_error "default.nix not found at $DEFAULT_NIX_FILE"
        exit 1
    fi
    
    local current_version
    current_version=$(grep -E '^\s*version\s*=' "$DEFAULT_NIX_FILE" | sed -E 's/.*version\s*=\s*"([^"]+)".*/\1/')
    
    if [ -z "$current_version" ]; then
        log_error "Could not extract current version from default.nix"
        exit 1
    fi
    
    echo "$current_version"
}

# Download and extract tarball
download_and_extract() {
    local version="$1"
    local temp_dir="$2"
    
    log_info "Downloading claude-code version $version..."
    local tarball_url="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$version.tgz"
    
    curl -L "$tarball_url" -o "$temp_dir/claude-code.tgz" || {
        log_error "Failed to download tarball from $tarball_url"
        exit 1
    }
    
    log_info "Extracting tarball..."
    mkdir -p "$temp_dir/extract"
    tar -xzf "$temp_dir/claude-code.tgz" -C "$temp_dir/extract" || {
        log_error "Failed to extract tarball"
        exit 1
    }
}

# Calculate source hash
calculate_source_hash() {
    local version="$1"
    
    local source_hash
    source_hash=$(nix-prefetch-url --type sha256 "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$version.tgz" 2>/dev/null)
    
    if [ -z "$source_hash" ]; then
        log_error "Failed to calculate source hash" >&2
        exit 1
    fi
    
    # Convert to SRI format
    local sri_hash
    sri_hash=$(nix hash to-sri --type sha256 "$source_hash" 2>/dev/null)
    echo "$sri_hash"
}

# Generate package-lock.json and calculate npmDepsHash
generate_package_lock_and_hash() {
    local temp_dir="$1"
    local version="$2"
    
    local package_dir="$temp_dir/extract/package"
    
    if [ ! -d "$package_dir" ]; then
        log_error "Package directory not found in extracted tarball"
        exit 1
    fi
    
    cd "$package_dir"
    
    # Generate package-lock.json
    npm install --package-lock-only --ignore-scripts 2>/dev/null || {
        log_warn "npm install failed, trying alternative approach..."
        # Create minimal package-lock.json if npm install fails
        cat > package-lock.json << EOF
{
  "name": "@anthropic-ai/claude-code",
  "version": "$version",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "@anthropic-ai/claude-code",
      "version": "$version"
    }
  }
}
EOF
    }
    
    if [ ! -f "package-lock.json" ]; then
        log_error "Failed to generate package-lock.json"
        exit 1
    fi
    
    # Copy package-lock.json to the script directory
    cp package-lock.json "$SCRIPT_DIR/" || {
        log_error "Failed to copy package-lock.json"
        exit 1
    }
    
    local npm_deps_hash
    npm_deps_hash=$(nix run nixpkgs#prefetch-npm-deps -- "$SCRIPT_DIR/package-lock.json" 2>/dev/null | grep -E '^sha256-' | head -1)
    
    if [ -z "$npm_deps_hash" ]; then
        log_error "Failed to calculate npmDepsHash"
        exit 1
    fi
    
    echo "$npm_deps_hash"
}

# Update default.nix with new version and hashes
update_default_nix() {
    local new_version="$1"
    local new_source_hash="$2"
    local new_npm_deps_hash="$3"
    
    log_info "Updating default.nix..."
    
    # Create backup
    cp "$DEFAULT_NIX_FILE" "$DEFAULT_NIX_FILE.backup"
    
    # Update version
    sed -i 's/version = "[^"]*";/version = "'"$new_version"'";/' "$DEFAULT_NIX_FILE"
    
    # Update source hash
    sed -i 's/hash = "[^"]*";/hash = "'"$new_source_hash"'";/' "$DEFAULT_NIX_FILE"
    
    # Update npmDepsHash
    sed -i 's/npmDepsHash = "[^"]*";/npmDepsHash = "'"$new_npm_deps_hash"'";/' "$DEFAULT_NIX_FILE"
    
    # Verify changes were made
    if grep -q "version = \"$new_version\"" "$DEFAULT_NIX_FILE" && \
       grep -q "hash = \"$new_source_hash\"" "$DEFAULT_NIX_FILE" && \
       grep -q "npmDepsHash = \"$new_npm_deps_hash\"" "$DEFAULT_NIX_FILE"; then
        log_success "default.nix updated successfully"
        rm "$DEFAULT_NIX_FILE.backup"
    else
        log_error "Failed to update default.nix properly"
        mv "$DEFAULT_NIX_FILE.backup" "$DEFAULT_NIX_FILE"
        exit 1
    fi
}

# Test the build
test_build() {
    log_info "Testing build with new configuration..."
    
    cd "$SCRIPT_DIR"
    
    if nix-build --no-out-link . >/dev/null 2>&1; then
        log_success "Build test passed!"
    else
        log_error "Build test failed!"
        log_info "Restoring backup..."
        if [ -f "$DEFAULT_NIX_FILE.backup" ]; then
            mv "$DEFAULT_NIX_FILE.backup" "$DEFAULT_NIX_FILE"
        fi
        exit 1
    fi
}

# Main function
main() {
    local force_update=false
    local version_override=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force_update=true
                shift
                ;;
            -v|--version)
                version_override="$2"
                shift 2
                ;;
            -h|--help)
                cat << EOF
Usage: $0 [OPTIONS]

Automatically update claude-code package to the latest version.

OPTIONS:
    -f, --force           Force update even if already at latest version
    -v, --version VERSION Update to specific version instead of latest
    -h, --help           Show this help message

EXAMPLES:
    $0                    # Update to latest version
    $0 --force            # Force update to latest version
    $0 --version 1.0.44   # Update to specific version

EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "Starting claude-code automated update..."
    
    # Check dependencies
    check_dependencies
    
    # Get versions
    local current_version
    current_version=$(get_current_version)
    log_info "Current version: $current_version"
    
    local target_version
    if [ -n "$version_override" ]; then
        target_version="$version_override"
        log_info "Target version (override): $target_version"
    else
        log_info "Fetching latest version from npm registry..."
        target_version=$(get_latest_version)
        log_info "Latest version: $target_version"
    fi
    
    # Check if update is needed
    if [ "$current_version" = "$target_version" ] && [ "$force_update" = false ]; then
        log_success "Already at target version $target_version"
        exit 0
    fi
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT
    
    # Download and extract
    download_and_extract "$target_version" "$temp_dir"
    
    # Calculate hashes
    log_info "Calculating source hash..."
    local source_hash
    source_hash=$(calculate_source_hash "$target_version")
    log_success "Source hash: $source_hash"
    
    log_info "Generating package-lock.json..."
    local npm_deps_hash
    npm_deps_hash=$(generate_package_lock_and_hash "$temp_dir" "$target_version")
    log_info "Calculating npmDepsHash..."
    log_success "npmDepsHash: $npm_deps_hash"
    
    # Update default.nix
    update_default_nix "$target_version" "$source_hash" "$npm_deps_hash"
    
    # Test build
    test_build
    
    log_success "Claude-code successfully updated from $current_version to $target_version!"
    log_info "Changes made:"
    log_info "  - Version: $current_version → $target_version"
    log_info "  - Source hash: updated"
    log_info "  - npmDepsHash: updated"
    log_info "  - package-lock.json: updated"
    
    log_info "You can now rebuild your system to use the updated package."
}

# Run main function
main "$@"