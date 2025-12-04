#!/usr/bin/env bash
# Agenix to SOPS Migration Script
# This script helps migrate existing agenix secrets to sops-nix

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=== Agenix to SOPS-nix Migration Script ==="
echo ""

# Check prerequisites
check_prerequisites() {
  local missing=0

  if ! command -v sops >/dev/null 2>&1; then
    log_error "sops is not installed. Install with: nix-shell -p sops"
    missing=1
  fi

  if ! command -v age >/dev/null 2>&1; then
    log_error "age is not installed. Install with: nix-shell -p age"
    missing=1
  fi

  if ! command -v ssh-to-age >/dev/null 2>&1; then
    log_error "ssh-to-age is not installed. Install with: nix-shell -p ssh-to-age"
    missing=1
  fi

  if [ $missing -eq 1 ]; then
    exit 1
  fi

  log_info "All prerequisites installed"
}

# Setup directories
setup_directories() {
  log_info "Creating SOPS secrets directory structure..."
  mkdir -p secrets/{common,hosts/{p620,razer,p510,dex5550,samsung}}
  log_info "Directory structure created"
}

# Extract host SSH keys and convert to age
extract_host_keys() {
  log_info "Extracting host SSH keys..."

  local hosts=("p620" "razer" "p510" "dex5550" "samsung")
  local host_keys=""

  for host in "${hosts[@]}"; do
    log_info "Processing $host..."

    # Try to get SSH key from known_hosts or direct connection
    if [ -f ~/.ssh/known_hosts ]; then
      key=$(grep "^$host" ~/.ssh/known_hosts | head -1 | cut -d' ' -f2-)
    fi

    if [ -z "${key:-}" ]; then
      log_warn "Could not find SSH key for $host in known_hosts"
      log_info "Attempting to fetch from host (if accessible)..."

      if ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
        key=$(ssh-keyscan -t ed25519 "$host" 2>/dev/null | grep ssh-ed25519 | cut -d' ' -f2-)
      fi
    fi

    if [ -n "${key:-}" ]; then
      age_key=$(echo "$key" | ssh-to-age)
      log_info "$host age key: $age_key"
      host_keys="${host_keys}  - &$host $age_key\n"
    else
      log_warn "Could not obtain SSH key for $host"
    fi
  done

  echo -e "$host_keys"
}

# Update .sops.yaml with actual keys
update_sops_config() {
  log_info "Updating .sops.yaml configuration..."

  # Get user's age public key
  if [ -f ~/.config/sops/age/keys.txt ]; then
    user_age_key=$(age-keygen -y ~/.config/sops/age/keys.txt)
    log_info "User age public key: $user_age_key"
  else
    log_warn "No age key found. Generating new one..."
    mkdir -p ~/.config/sops/age
    age-keygen -o ~/.config/sops/age/keys.txt
    user_age_key=$(age-keygen -y ~/.config/sops/age/keys.txt)
    log_info "Generated new age key: $user_age_key"
  fi

  # Get host keys
  host_keys=$(extract_host_keys)

  # Update .sops.yaml with actual keys
  if [ -f .sops.yaml ]; then
    log_warn ".sops.yaml already exists. Creating backup..."
    cp .sops.yaml .sops.yaml.backup
  fi

  log_info "Keys extracted. Please update .sops.yaml manually with the correct age keys"
}

# Function to decrypt agenix secret
decrypt_agenix() {
  local secret_file=$1
  if [ -f "$secret_file" ]; then
    if command -v agenix >/dev/null 2>&1; then
      agenix -d "$secret_file" 2>/dev/null || echo ""
    else
      log_warn "agenix not available, cannot decrypt $secret_file"
      echo "PLACEHOLDER_FOR_$secret_file"
    fi
  else
    log_warn "Secret file $secret_file not found"
    echo ""
  fi
}

# Migrate secrets
migrate_secrets() {
  log_info "Migrating secrets from agenix to SOPS..."

  # User passwords
  log_info "Creating users secrets file..."
  cat >secrets/common/users.yaml <<EOF
# User passwords - hashed passwords for NixOS users
users:
  olafkfreund:
    password: "$(decrypt_agenix secrets/user-password-olafkfreund.age)"
EOF

  # API keys
  log_info "Creating API keys secrets file..."
  cat >secrets/common/api-keys.yaml <<EOF
# API Keys for various services
api_keys:
  openai: "$(decrypt_agenix secrets/api-openai.age)"
  anthropic: "$(decrypt_agenix secrets/api-anthropic.age)"
  gemini: "$(decrypt_agenix secrets/api-gemini.age)"
  github: "$(decrypt_agenix secrets/api-github-token.age)"
EOF

  # Network secrets
  log_info "Creating network secrets file..."
  cat >secrets/common/network.yaml <<EOF
# Network-related secrets
network:
  wifi_password: "$(decrypt_agenix secrets/wifi-password.age)"
  tailscale_auth_key: "$(decrypt_agenix secrets/tailscale-auth-key.age)"
EOF

  log_info "Secret files created (unencrypted)"
}

# Encrypt secrets with SOPS
encrypt_secrets() {
  log_info "Encrypting secrets with SOPS..."

  if [ ! -f .sops.yaml ]; then
    log_error ".sops.yaml not found! Please create it first"
    exit 1
  fi

  # Check if we have valid age keys
  export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

  if [ ! -f "$SOPS_AGE_KEY_FILE" ]; then
    log_error "Age key file not found at $SOPS_AGE_KEY_FILE"
    exit 1
  fi

  # Encrypt each secrets file
  for file in secrets/common/*.yaml; do
    if [ -f "$file" ]; then
      log_info "Encrypting $file..."
      sops -e -i "$file" || {
        log_error "Failed to encrypt $file"
        log_info "You may need to manually edit .sops.yaml with correct age keys"
        exit 1
      }
    fi
  done

  log_info "All secrets encrypted successfully"
}

# Verify encrypted secrets
verify_secrets() {
  log_info "Verifying encrypted secrets..."

  for file in secrets/common/*.yaml; do
    if [ -f "$file" ]; then
      log_info "Checking $file..."
      if sops -d "$file" >/dev/null 2>&1; then
        log_info "✓ $file can be decrypted"
      else
        log_error "✗ $file cannot be decrypted"
      fi
    fi
  done
}

# Main execution
main() {
  log_info "Starting migration process..."

  check_prerequisites
  setup_directories
  update_sops_config

  echo ""
  log_warn "Please ensure .sops.yaml has the correct age keys before continuing"
  log_warn "You can get host age keys by running:"
  log_warn "  ssh-keyscan HOSTNAME | ssh-to-age"
  echo ""
  read -p "Press Enter to continue with migration, or Ctrl+C to abort..."

  migrate_secrets

  echo ""
  log_warn "Please review the unencrypted secrets files and update them as needed"
  read -p "Press Enter to encrypt the secrets, or Ctrl+C to abort..."

  encrypt_secrets
  verify_secrets

  echo ""
  log_info "Migration complete!"
  echo ""
  echo "Next steps:"
  echo "1. Update your flake.nix to use sops-nix instead of agenix"
  echo "2. Update host configurations to import the SOPS module"
  echo "3. Test on one host: nixos-rebuild test"
  echo "4. If successful, deploy to all hosts"
  echo "5. Remove old agenix secrets after verification"
  echo ""
  echo "To edit secrets: sops secrets/common/api-keys.yaml"
  echo "To view secrets: sops -d secrets/common/api-keys.yaml"
}

# Run main function
main "$@"
