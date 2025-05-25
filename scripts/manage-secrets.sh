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
NC='\033[0m' # No Color

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

# Check if agenix is available, with helpful installation instructions
check_agenix() {
  if ! command -v agenix &> /dev/null; then
    error "agenix not found. Please enable secrets management in your NixOS configuration:

1. Enable the secrets module in your host configuration:
   modules.security.secrets.enable = true;

2. Rebuild your system:
   sudo nixos-rebuild switch --flake .#<hostname>

3. Then run this script again."
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

# Generate SSH keys if they don't exist
setup_keys() {
  local key_path="$HOME/.ssh/id_ed25519"
  
  if [[ ! -f "$key_path" ]]; then
    log "Generating SSH key for secrets management..."
    ssh-keygen -t ed25519 -f "$key_path" -N ""
    log "SSH key generated at $key_path"
    log "Public key: $(cat "$key_path.pub")"
    warn "Add this public key to secrets/secrets.nix"
  else
    log "SSH key already exists at $key_path"
    log "Public key: $(cat "$key_path.pub")"
  fi

  # Check for host keys
  if [[ -f "/etc/ssh/ssh_host_ed25519_key.pub" ]]; then
    log "Host public key: $(cat /etc/ssh/ssh_host_ed25519_key.pub)"
    warn "Add this host public key to secrets/secrets.nix"
  else
    warn "Host SSH key not found. Generate with: sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''"
  fi
}

# Create a new secret
create_secret() {
  local secret_name="$1"
  
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
  
  if [[ ! -f "$SECRETS_DIR/$secret_name.age" ]]; then
    error "Secret $secret_name does not exist. Use 'create' first."
  fi
  
  log "Editing secret: $secret_name"
  cd "$SECRETS_DIR"
  run_agenix -e "$secret_name.age"
}

# Rekey all secrets (useful when keys change)
rekey_secrets() {
  log "Rekeying all secrets..."
  cd "$SECRETS_DIR"
  run_agenix -r
}

# List all secrets
list_secrets() {
  log "Available secrets:"
  if [[ -d "$SECRETS_DIR" ]]; then
    find "$SECRETS_DIR" -name "*.age" -exec basename {} .age \; | sort
  else
    warn "No secrets directory found"
  fi
}

# Initialize secrets directory and configuration
init_secrets() {
  log "Initializing secrets management..."
  
  # Create secrets directory
  mkdir -p "$SECRETS_DIR"
  
  # Create .gitkeep if it doesn't exist
  if [[ ! -f "$SECRETS_DIR/.gitkeep" ]]; then
    echo "# This file ensures the secrets directory is tracked by git" > "$SECRETS_DIR/.gitkeep"
    echo "# but the actual .age files will be ignored" >> "$SECRETS_DIR/.gitkeep"
    log "Created $SECRETS_DIR/.gitkeep"
  fi
  
  # Create secrets.nix template if it doesn't exist
  if [[ ! -f "$SECRETS_DIR/secrets.nix" ]]; then
    cat > "$SECRETS_DIR/secrets.nix" << 'EOF'
# This file defines which keys can decrypt which secrets
# Run: agenix -e <secret-name>.age
let
  # User public keys (replace with your actual keys)
  olafkfreund = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... olafkfreund@nixos";

  # Host public keys (extract with: sudo cat /etc/ssh/ssh_host_ed25519_key.pub)
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@p620";
  razer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@razer";
  p510 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@p510";
  dex5550 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@dex5550";

  # Key groups
  allUsers = [olafkfreund];
  allHosts = [p620 razer p510 dex5550];
  workstations = [p620 razer];
  servers = [p510 dex5550];
in {
  # User secrets - accessible by user and their primary hosts
  "user-password-olafkfreund.age".publicKeys = allUsers ++ allHosts;
  "github-token.age".publicKeys = allUsers ++ workstations;
  
  # Host secrets - accessible by specific hosts
  "ssh-host-ed25519-key.age".publicKeys = allUsers ++ allHosts;
  "wifi-password.age".publicKeys = allUsers ++ [razer]; # Only laptop needs WiFi
  
  # Service secrets - accessible by relevant hosts
  "docker-auth.age".publicKeys = allUsers ++ allHosts;
  "postgres-password.age".publicKeys = allUsers ++ servers;
}
EOF
    log "Created $SECRETS_DIR/secrets.nix template"
    warn "Please update the public keys in $SECRETS_DIR/secrets.nix with your actual keys"
  fi
  
  # Update .gitignore
  local gitignore="$NIXOS_DIR/.gitignore"
  if [[ -f "$gitignore" ]] && ! grep -q "secrets/\*.age" "$gitignore"; then
    echo "" >> "$gitignore"
    echo "# Secrets management" >> "$gitignore"
    echo "secrets/*.age" >> "$gitignore"
    log "Updated .gitignore to exclude .age files"
  fi
  
  log "Secrets management initialized successfully!"
  log "Next steps:"
  log "1. Run './scripts/manage-secrets.sh setup' to generate SSH keys"
  log "2. Update secrets/secrets.nix with your actual public keys"
  log "3. Enable secrets in your NixOS configuration"
  log "4. Run 'sudo nixos-rebuild switch' to apply changes"
}

# Show usage
usage() {
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  init               Initialize secrets management"
  echo "  setup              Generate SSH keys for secrets management"
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