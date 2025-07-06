#!/bin/bash

# Script to encrypt API keys from ~/.openai.sh using agenix
# This script will help you migrate from plaintext API keys to encrypted secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$NIXOS_DIR/secrets"
OPENAI_FILE="$HOME/.openai.sh"

echo "🔐 API Keys Encryption Script"
echo "============================"
echo ""

# Check if agenix is available
if ! command -v agenix &> /dev/null; then
    echo "❌ Error: agenix command not found"
    echo "Please install agenix or run from a NixOS system with agenix configured"
    exit 1
fi

# Check if ~/.openai.sh exists
if [[ ! -f "$OPENAI_FILE" ]]; then
    echo "❌ Error: ~/.openai.sh not found"
    echo "Expected API keys file at: $OPENAI_FILE"
    exit 1
fi

echo "📁 Found API keys file: $OPENAI_FILE"
echo "📁 Secrets directory: $SECRETS_DIR"
echo ""

# Create secrets directory if it doesn't exist
mkdir -p "$SECRETS_DIR"

# Function to extract and encrypt a key
encrypt_key() {
    local key_name="$1"
    local env_var="$2"
    local secret_file="secrets/api-${key_name}.age"  # Relative path for agenix
    local full_secret_path="$SECRETS_DIR/api-${key_name}.age"  # Full path for file operations
    
    echo "🔍 Processing $env_var..."
    
    # Extract the key value from ~/.openai.sh
    local key_value=$(grep "^export $env_var=" "$OPENAI_FILE" | sed "s/^export $env_var=//" | sed 's/^"//' | sed 's/"$//')
    
    if [[ -z "$key_value" ]]; then
        echo "⚠️  Warning: $env_var not found or empty in $OPENAI_FILE"
        return
    fi
    
    # Check if secret file already exists
    if [[ -f "$full_secret_path" ]]; then
        echo "⚠️  Secret file already exists: $full_secret_path"
        read -p "   Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "   Skipping $key_name"
            return
        fi
    fi
    
    echo "🔐 Encrypting $key_name..."
    echo "   Key preview: ${key_value:0:20}..."
    
    # Change to nixos directory for agenix
    cd "$NIXOS_DIR"
    
    # Use agenix with the relative path and pipe the key value
    if echo -n "$key_value" | agenix -e "$secret_file"; then
        echo "✅ Successfully encrypted $key_name to $secret_file"
    else
        echo "❌ Failed to encrypt $key_name"
        echo "   Make sure you're in the NixOS directory and secrets.nix is configured correctly"
    fi
    
    echo ""
}

# Function to show current keys
show_current_keys() {
    echo "📋 Current API keys in $OPENAI_FILE:"
    echo "=================================="
    
    while IFS= read -r line; do
        if [[ $line =~ ^export\ ([^=]+)= ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local value_preview=$(echo "$line" | sed 's/.*=//' | sed 's/^"//' | sed 's/"$//' | head -c 20)
            echo "   $var_name: ${value_preview}..."
        fi
    done < "$OPENAI_FILE"
    echo ""
}

# Function to verify encryption
verify_encryption() {
    echo "🔍 Verifying encrypted secrets..."
    echo "==============================="
    
    local keys=("openai" "gemini" "anthropic" "langchain" "github-token")
    
    for key in "${keys[@]}"; do
        local secret_file="$SECRETS_DIR/api-${key}.age"
        if [[ -f "$secret_file" ]]; then
            echo "✅ $key: Encrypted file exists"
        else
            echo "❌ $key: Missing encrypted file"
        fi
    done
    echo ""
}

# Main execution
echo "This script will encrypt your API keys from ~/.openai.sh"
echo "and store them as age-encrypted secrets for NixOS."
echo ""

show_current_keys

read -p "Continue with encryption? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "🚀 Starting encryption process..."
echo ""

# Encrypt each API key
encrypt_key "openai" "OPENAI_API_KEY"
encrypt_key "gemini" "GEMINI_API_KEY" 
encrypt_key "anthropic" "ANTHROPIC_API_KEY"
encrypt_key "langchain" "LANGCHAIN_API_KEY"
encrypt_key "github-token" "GITHUB_TOKEN"

verify_encryption

echo "🎉 Encryption complete!"
echo ""
echo "Next steps:"
echo "1. Rebuild your NixOS configuration: sudo nixos-rebuild switch"
echo "2. Check API keys status: api-keys-status"
echo "3. Test environment variables: echo \$OPENAI_API_KEY"
echo "4. Optionally remove ~/.openai.sh (backup it first!)"
echo ""
echo "Your API keys are now securely encrypted and will be available"
echo "as environment variables on all configured hosts."