#!/usr/bin/env bash

# NixOS Secrets Management Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$NIXOS_DIR/secrets"
SECRETS_CONFIG="$NIXOS_DIR/secrets.nix"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# Check if secrets.nix exists
check_secrets_config() {
  if [[ ! -f "$SECRETS_CONFIG" ]]; then
    error "secrets.nix not found at $SECRETS_CONFIG. Run '$0 init' first."
  fi
}

# Alternative function to run agenix
run_agenix() {
  if command -v agenix &> /dev/null; then
    cd "$NIXOS_DIR"  # Run from config root
    agenix "$@"
  else
    log "Running agenix through nix..."
    cd "$NIXOS_DIR"
    nix run github:ryantm/agenix -- "$@"
  fi
}

# Check current secrets configuration
check_current_config() {
  if [[ -f "$SECRETS_CONFIG" ]]; then
    log "Current secrets.nix configuration:"
    echo ""
    # Show the secret definitions (just the attribute names)
    grep -E '^\s*".*\.age"\.publicKeys' "$SECRETS_CONFIG" | sed 's/.publicKeys.*//' | sed 's/^\s*/  /'
    echo ""
  fi
}

# Initialize secrets management
init_secrets() {
  log "Initializing secrets management..."
  
  # Create secrets directory
  mkdir -p "$SECRETS_DIR"
  
  # Create secrets.nix in the root directory (standard agenix location)
  if [[ ! -f "$SECRETS_CONFIG" ]]; then
    cat > "$SECRETS_CONFIG" << 'EOF'
# This file defines which keys can decrypt which secrets
# Run: agenix -e <secret-name>.age
let
  # User public keys - replace with your actual keys
  # Get your key with: cat ~/.ssh/id_ed25519.pub
  olafkfreund = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... olafkfreund@nixos";

  # Host public keys - extract with: sudo cat /etc/ssh/ssh_host_ed25519_key.pub
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@p620";
  razer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@razer";
  p510 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@p510";
  dex5550 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@dex5550";

  # Key groups
  allUsers = [ olafkfreund ];
  allHosts = [ p620 razer p510 dex5550 ];
  workstations = [ p620 razer ];
  servers = [ p510 dex5550 ];
in
{
  # Paths are relative to this file (project root)
  # Make sure these match your actual .age file locations
  "secrets/user-password-olafkfreund.age".publicKeys = allUsers ++ allHosts;
  "secrets/github-token.age".publicKeys = allUsers ++ workstations;
  "secrets/wifi-password.age".publicKeys = allUsers ++ [ razer ];
  "secrets/docker-auth.age".publicKeys = allUsers ++ allHosts;
  "secrets/postgres-password.age".publicKeys = allUsers ++ servers;
}
EOF
    log "Created $SECRETS_CONFIG"
  fi
  
  # Update .gitignore
  local gitignore="$NIXOS_DIR/.gitignore"
  if ! grep -q "secrets.nix" "$gitignore" 2>/dev/null; then
    cat >> "$gitignore" << 'EOF'

# Secrets management
secrets.nix
secrets/*.age
EOF
    log "Updated .gitignore"
  fi
  
  log "Secrets management initialized!"
  log ""
  log "Next steps:"
  log "1. Run './scripts/get-keys.sh' to get your SSH public keys"
  log "2. Edit secrets.nix and replace the placeholder keys with real ones"
  log "3. Run './scripts/manage-secrets.sh rekey' to update existing secrets"
}

# Create a new secret
create_secret() {
  local secret_name="$1"
  check_secrets_config
  
  # Add secrets/ prefix if not present
  if [[ ! "$secret_name" == secrets/* ]]; then
    secret_name="secrets/$secret_name"
  fi
  
  if [[ -f "$NIXOS_DIR/$secret_name.age" ]]; then
    warn "Secret $secret_name already exists. Use 'edit' to modify it."
    return 1
  fi
  
  log "Creating secret: $secret_name"
  run_agenix -e "$secret_name.age"
}

# Edit an existing secret
edit_secret() {
  local secret_name="$1"
  check_secrets_config
  
  # Add secrets/ prefix if not present
  if [[ ! "$secret_name" == secrets/* ]]; then
    secret_name="secrets/$secret_name"
  fi
  
  if [[ ! -f "$NIXOS_DIR/$secret_name.age" ]]; then
    error "Secret $secret_name does not exist. Available secrets:"
    list_secrets
    return 1
  fi
  
  log "Editing secret: $secret_name"
  run_agenix -e "$secret_name.age"
}

# Rekey all secrets
rekey_secrets() {
  check_secrets_config
  log "Rekeying all secrets..."
  
  # Show what secrets will be rekeyed
  log "The following secrets will be rekeyed:"
  list_secrets
  
  run_agenix -r
  
  if [[ $? -eq 0 ]]; then
    log "✅ All secrets successfully rekeyed!"
  else
    error "❌ Rekeying failed. Check your secrets.nix configuration."
  fi
}

# List all secrets
list_secrets() {
  if [[ -d "$SECRETS_DIR" ]]; then
    find "$SECRETS_DIR" -name "*.age" -type f | sed "s|$NIXOS_DIR/||" | sort
  else
    warn "No secrets found"
  fi
}

# Status check
status() {
  log "Secrets Management Status:"
  echo ""
  
  # Check if secrets.nix exists
  if [[ -f "$SECRETS_CONFIG" ]]; then
    log "✅ secrets.nix configuration found"
  else
    warn "❌ secrets.nix not found"
  fi
  
  # Check available secrets
  local secret_count=$(find "$SECRETS_DIR" -name "*.age" 2>/dev/null | wc -l)
  log "📁 Found $secret_count secret files"
  
  # Show current configuration
  check_current_config
  
  # Check if agenix is available
  if command -v agenix &> /dev/null; then
    log "✅ agenix command available"
  else
    warn "⚠️  agenix not in PATH (will use nix run)"
  fi
}

# Show usage
usage() {
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  init               Initialize secrets management"
  echo "  status             Show current secrets status"
  echo "  create <name>      Create a new secret"
  echo "  edit <name>        Edit an existing secret"
  echo "  rekey              Rekey all secrets with current keys"
  echo "  list               List all available secrets"
  echo ""
  echo "Examples:"
  echo "  $0 init"
  echo "  $0 status"
  echo "  $0 create user-password-olafkfreund"
  echo "  $0 edit user-password-olafkfreund"
  echo "  $0 list"
}

# Main logic
main() {
  case "${1:-help}" in
    init) init_secrets ;;
    status) status ;;
    create)
      [[ $# -lt 2 ]] && error "Secret name required"
      create_secret "$2"
      ;;
    edit)
      [[ $# -lt 2 ]] && error "Secret name required"
      edit_secret "$2"
      ;;
    rekey) rekey_secrets ;;
    list) list_secrets ;;
    *) usage ;;
  esac
}

main "$@"