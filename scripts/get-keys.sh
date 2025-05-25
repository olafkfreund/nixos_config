#!/usr/bin/env bash

# Script to extract SSH public keys for secrets.nix
set -euo pipefail

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

info() {
  echo -e "${BLUE}[KEY]${NC} $1"
}

log "Extracting SSH public keys for secrets management..."
echo ""

# Get user public key
if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
  info "User public key (olafkfreund):"
  user_key=$(cat "$HOME/.ssh/id_ed25519.pub")
  echo "  olafkfreund = \"$user_key\";"
  echo ""
else
  warn "User SSH key not found at $HOME/.ssh/id_ed25519.pub"
  warn "Generate with: ssh-keygen -t ed25519 -f $HOME/.ssh/id_ed25519 -N ''"
  echo ""
fi

# Get host public key
if [[ -f "/etc/ssh/ssh_host_ed25519_key.pub" ]]; then
  info "Host public key ($(hostname)):"
  host_key=$(cat "/etc/ssh/ssh_host_ed25519_key.pub")
  hostname=$(hostname)
  echo "  $hostname = \"$host_key\";"
  echo ""
else
  warn "Host SSH key not found at /etc/ssh/ssh_host_ed25519_key.pub"
  warn "Generate with: sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''"
  echo ""
fi

# Show which keys were used to encrypt the existing secret
if [[ -f "secrets/user-password-olafkfreund.age" ]]; then
  info "Keys that can decrypt the existing secret:"
  # Extract recipient key fingerprints from the .age file
  head -n 20 "secrets/user-password-olafkfreund.age" | grep "^->" | while read -r line; do
    echo "  $line"
  done
  echo ""
  warn "These keys must be included in your secrets.nix file"
fi

log "Update secrets.nix with these actual public keys"