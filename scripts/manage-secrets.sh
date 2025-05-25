#!/usr/bin/env bash

# NixOS Secrets Management Script
# Usage: ./scripts/manage-secrets.sh [create|edit|rekey|list]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$NIXOS_DIR/secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if secrets.nix exists and has proper format
check_secrets_config() {
  if [[ ! -f "$SECRETS_DIR/secrets.nix" ]]; then
    error "secrets.nix not found. Run '$0 init' first to create the configuration."
  fi
  
  # Basic validation that secrets.nix has the expected structure
  if ! grep -q "publicKeys" "$SECRETS_DIR/secrets.nix"; then
    error "secrets.nix appears to be invalid. It should contain publicKeys definitions."
  fi
}

# Alternative function to run agenix through nix run if not in PATH
run_agenix() {
  if command -v agenix &> /dev/null; then
    agenix "$@"
  else
    log "Running agenix through nix..."
    nix run github:ryantm/agenix -- "$@"
  fi
}

# Initialize secrets directory and configuration
init_secrets() {
  log "Initializing secrets management..."
  
  # Create secrets directory
  mkdir -p "$SECRETS_DIR"
  
  # Create .gitkeep if it doesn't exist
  if [[ ! -f "$SECRETS_DIR/.gitkeep" ]]; then
    cat > "$SECRETS_DIR/.gitkeep" << 'EOF'
# This file ensures the secrets directory is tracked by git
# The actual .age files will be created when you run the setup script
EOF
    log "Created $SECRETS_DIR/.gitkeep"
  fi
  
  # Create secrets.nix template if it doesn't exist
  if [[ ! -f "$SECRETS_DIR/secrets.nix" ]]; then
    cat > "$SECRETS_DIR/secrets.nix" << 'EOF'
# This file defines which keys can decrypt which secrets
# Run: agenix -e <secret-name>.age
let
  # User public keys - replace with your actual keys
  # Get your key with: cat ~/.ssh/id_ed25519.pub
  olafkfreund = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... olafkfreund@nixos";

  # Host public keys - extract with: sudo cat /etc/ssh/ssh_host_ed25519_key.pub
  # Replace these with your actual host keys
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@p620";
  razer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@razer";
  p510 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@p510";
  dex5550 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@dex5550";

  # Key groups for easier management
  allUsers = [ olafkfreund ];
  allHosts = [ p620 razer p510 dex5550 ];
  workstations = [ p620 razer ];
  servers = [ p510 dex5550 ];
in
{
  # User secrets - accessible by user and their primary hosts
  "user-password-olafkfreund.age".publicKeys = allUsers ++ allHosts;
  "github-token.age".publicKeys = allUsers ++ workstations;
  
  # Host secrets - accessible by specific hosts
  "ssh-host-ed25519-key.age".publicKeys = allUsers ++ allHosts;
  "wifi-password.age".publicKeys = allUsers ++ [ razer ]; # Only laptop needs WiFi
  
  # Service secrets - accessible by relevant hosts
  "docker-auth.age".publicKeys = allUsers ++ allHosts;
  "postgres-password.age".publicKeys = allUsers ++ servers;
}
EOF
    log "Created $SECRETS_DIR/secrets.nix template"
    warn "Please update the public keys in $SECRETS_DIR/secrets.nix with your actual keys"
    log "Run './scripts/get-keys.sh' to extract your current SSH keys"
  fi
  
  # Update .gitignore
  local gitignore="$NIXOS_DIR/.gitignore"
  if ! grep -q "secrets/\*.age" "$gitignore" 2>/dev/null; then
    cat >> "$gitignore" << 'EOF'

# Secrets management
secrets/*.age
EOF
    log "Updated .gitignore to exclude .age files"
  fi
  
  log "Secrets management initialized successfully!"
  log ""
  log "Next steps:"
  log "1. Run './scripts/get-keys.sh' to get your SSH public keys"
  log "2. Update secrets/secrets.nix with the actual public keys"
  log "3. Run './scripts/manage-secrets.sh rekey' to update existing secrets"
}

# Generate SSH keys if they don't exist
setup_keys() {
  local key_path="$HOME/.ssh/id_ed25519"
  
  if [[ ! -f "$key_path" ]]; then
    log "Generating SSH key for secrets management..."
    ssh-keygen -t ed25519 -f "$key_path" -N ""
    log "SSH key generated at $key_path"
  fi
  
  log "Running key extraction script..."
  "$SCRIPT_DIR/get-keys.sh"
}

# Create a new secret
create_secret() {
  local secret_name="$1"
  
  check_secrets_config
  
  if [[ -f "$SECRETS_DIR/$secret_name.age" ]]; then
    warn "Secret $secret_name already exists. Use 'edit' to modify it."
    return 1
  fi
  
  log "Creating secret: $secret_name"
  cd "$SECRETS_DIR"
  run_agenix -e "$secret_name.age"
}

# Edit an existing secret
edit_secret() {
  local secret_name="$1"
  
  check_secrets_config
  
  if [[ ! -f "$SECRETS_DIR/$secret_name.age" ]]; then
    error "Secret $secret_name does not exist. Use 'create' first."
  fi
  
  log "Editing secret: $secret_name"
  cd "$SECRETS_DIR"
  run_agenix -e "$secret_name.age"
}

# Rekey all secrets (useful when keys change)
rekey_secrets() {
  check_secrets_config
  
  log "Rekeying all secrets..."
  cd "$SECRETS_DIR"
  run_agenix -r
}

# List all secrets
list_secrets() {
  log "Available secrets:"
  if [[ -d "$SECRETS_DIR" ]]; then
    find "$SECRETS_DIR" -name "*.age" -exec basename {} .age \; 2>/dev/null | sort || echo "No secrets found"
  else
    warn "No secrets directory found. Run '$0 init' first."
  fi
}

# Show usage
usage() {
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  init               Initialize secrets management"
  echo "  setup              Generate SSH keys and extract public keys"
  echo "  create <name>      Create a new secret"
  echo "  edit <name>        Edit an existing secret"
  echo "  rekey              Rekey all secrets with current keys"
  echo "  list               List all available secrets"
  echo ""
  echo "Examples:"
  echo "  $0 init"
  echo "  $0 setup"
  echo "  $0 create user-password-olafkfreund"
  echo "  $0 edit github-token"
  echo "  $0 list"
}

# Main script logic
main() {
  case "${1:-help}" in
    init)
      init_secrets
      ;;
    setup)
      setup_keys
      ;;
    create)
      if [[ $# -lt 2 ]]; then
        error "Secret name required. Usage: $0 create <secret-name>"
      fi
      create_secret "$2"
      ;;
    edit)
      if [[ $# -lt 2 ]]; then
        error "Secret name required. Usage: $0 edit <secret-name>"
      fi
      edit_secret "$2"
      ;;
    rekey)
      rekey_secrets
      ;;
    list)
      list_secrets
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      error "Unknown command: $1"
      usage
      ;;
  esac
}

main "$@"