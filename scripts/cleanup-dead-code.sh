#!/usr/bin/env bash
# Script to identify and optionally remove dead code from NixOS configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧹 NixOS Configuration Dead Code Cleanup"
echo "========================================"

# Function to find commented code blocks
find_commented_code() {
    echo "🔍 Finding commented code blocks..."
    
    echo "Commented nixcord references:"
    rg "#.*nixcord" --type nix "$CONFIG_DIR" || true
    
    echo "Large commented blocks (>3 lines):"
    rg -U "^\s*#.*\n(\s*#.*\n){3,}" --type nix "$CONFIG_DIR" || true
    
    echo "Commented imports:"
    rg "^\s*#.*import" --type nix "$CONFIG_DIR" || true
}

# Function to find unused imports
find_unused_imports() {
    echo "🔍 Finding potentially unused imports..."
    
    # Find files with many imports but few references
    find "$CONFIG_DIR" -name "*.nix" -exec bash -c '
        file="$1"
        import_count=$(grep -c "import" "$file" 2>/dev/null || echo 0)
        content_lines=$(wc -l < "$file")
        
        if [ "$import_count" -gt 3 ] 2>/dev/null && [ "$content_lines" -lt 50 ] 2>/dev/null; then
            echo "$file: $import_count imports in $content_lines lines (potential over-importing)"
        fi
    ' _ {} \;
}

# Function to find unused files
find_unused_files() {
    echo "🔍 Finding potentially unused files..."
    
    # Find .nix files that aren't imported anywhere
    find "$CONFIG_DIR" -name "*.nix" ! -name "flake.nix" | while read -r file; do
        filename=$(basename "$file" .nix)
        relative_path=${file#$CONFIG_DIR/}
        
        # Check if file is referenced anywhere
        if ! rg -q "$filename|$relative_path" --type nix "$CONFIG_DIR" --exclude-file "$file"; then
            echo "Potentially unused: $relative_path"
        fi
    done
}

# Function to find duplicate files
find_duplicate_files() {
    echo "🔍 Finding duplicate files..."
    
    # Find files with identical content
    find "$CONFIG_DIR" -name "*.nix" -exec md5sum {} \; | sort | uniq -d -w32 | while read -r hash file; do
        echo "Duplicate content found in: $file"
        # Find all files with same hash
        find "$CONFIG_DIR" -name "*.nix" -exec md5sum {} \; | grep "^$hash" | cut -d' ' -f2-
        echo "---"
    done
}

# Function to find hardcoded values that should be variables
find_hardcoded_values() {
    echo "🔍 Finding hardcoded values..."
    
    echo "Hardcoded IP addresses:"
    rg '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b' --type nix "$CONFIG_DIR" || true
    
    echo "Hardcoded paths:"
    rg '"/[^"]*"' --type nix "$CONFIG_DIR" | head -10 || true
    
    echo "Hardcoded versions:"
    rg '\bversion\s*=\s*"[0-9]+\.[0-9]+' --type nix "$CONFIG_DIR" || true
}

# Function to analyze feature flag usage
analyze_feature_flags() {
    echo "🔍 Analyzing feature flag patterns..."
    
    echo "Feature flags set to true explicitly:"
    rg 'enable\s*=\s*true' --type nix "$CONFIG_DIR" | wc -l
    
    echo "Feature flags with mkForce:"
    rg 'mkForce.*enable' --type nix "$CONFIG_DIR" | wc -l
    
    echo "Identical feature flag blocks:"
    find "$CONFIG_DIR" -name "*_home.nix" -exec bash -c '
        echo "=== $1 ==="
        grep -A 20 "features = {" "$1" | head -20
    ' _ {} \;
}

# Main execution
case "${1:-analysis}" in
    "analysis"|"analyze")
        echo "Running analysis only (no changes made)..."
        find_commented_code
        echo
        find_unused_imports  
        echo
        find_unused_files
        echo
        find_duplicate_files
        echo
        find_hardcoded_values
        echo
        analyze_feature_flags
        ;;
    "clean")
        echo "⚠️  DANGER: This will modify your configuration!"
        echo "Make sure you have backups before proceeding."
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Removing commented nixcord references..."
            find "$CONFIG_DIR" -name "*.nix" -exec sed -i '/^\s*#.*nixcord/d' {} \;
            
            echo "Removing large commented blocks..."
            # This is more complex and should be done manually
            echo "Manual review recommended for commented blocks."
            
            echo "✅ Basic cleanup completed"
        else
            echo "Cleanup cancelled"
        fi
        ;;
    *)
        echo "Usage: $0 [analysis|clean]"
        echo "  analysis - Analyze configuration for dead code (default)"
        echo "  clean    - Remove identified dead code (DESTRUCTIVE)"
        ;;
esac

echo "✅ Dead code analysis complete"