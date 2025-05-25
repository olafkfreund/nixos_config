#!/usr/bin/env bash

# Script to recover from secrets key mismatch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$NIXOS_DIR/secrets"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

log "Secret Recovery Process"
echo "======================"
echo ""

# Check if user can decrypt the existing secret
check_decryption() {
  local secret_file="$1"
  if command -v agenix &> /dev/null; then
    cd "$NIXOS_DIR"
    if agenix -d "$secret_file" &> /dev/null; then
      return 0
    else
      return 1
    fi
  else
    cd "$NIXOS_DIR"
    if nix run github:ryantm/agenix -- -d "$secret_file" &> /dev/null; then
      return 0
    else
      return 1
    fi
  fi
}

# Backup and recreate secret
recreate_secret() {
  local secret_name="$1"
  local secret_file="secrets/${secret_name}.age"
  
  warn "Cannot decrypt $secret_file with current keys"
  echo ""
  echo "Options:"
  echo "1. If you have the private key that was used to encrypt this secret:"
  echo "   - Add that public key to secrets.nix"
  echo "   - Run rekey again"
  echo ""
  echo "2. If you don't have the original key:"
  echo "   - The secret needs to be recreated"
  echo "   - This will lose the current secret content"
  echo ""
  
  read -p "Do you want to recreate the secret? (y/N): " choice
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    # Backup the old secret
    mv "$secret_file" "${secret_file}.backup.$(date +%s)"
    log "Backed up old secret to ${secret_file}.backup.*"
    
    # Create new secret
    log "Creating new secret: $secret_name"
    cd "$NIXOS_DIR"
    if command -v agenix &> /dev/null; then
      agenix -e "$secret_file"
    else
      nix run github:ryantm/agenix -- -e "$secret_file"
    fi
    
    log "✅ Secret recreated successfully"
  else
    log "Secret not recreated. Add the correct keys to secrets.nix first."
  fi
}

# Main recovery process
main() {
  # Check the main secret first
  if [[ -f "$SECRETS_DIR/user-password-olafkfreund.age" ]]; then
    if check_decryption "secrets/user-password-olafkfreund.age"; then
      log "✅ Can decrypt user-password-olafkfreund.age"
    else
      recreate_secret "user-password-olafkfreund"
    fi
  fi
  
  # Check other secrets
  for secret_file in "$SECRETS_DIR"/*.age; do
    if [[ -f "$secret_file" ]]; then
      secret_name=$(basename "$secret_file" .age)
      relative_path="secrets/$secret_name.age"
      
      if [[ "$secret_name" != "user-password-olafkfreund" ]]; then
        if check_decryption "$relative_path"; then
          log "✅ Can decrypt $secret_name.age"
        else
          warn "❌ Cannot decrypt $secret_name.age"
          echo "  You may need to recreate this secret or add the correct keys"
        fi
      fi
    fi
  done
  
  echo ""
  log "Recovery process complete"
  log "Next steps:"
  log "1. Update secrets.nix with your actual SSH public keys"
  log "2. Run: ./scripts/manage-secrets.sh rekey"
  log "3. Verify: ./scripts/manage-secrets.sh status"
}

main "$@"