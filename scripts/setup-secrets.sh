#!/usr/bin/env bash

# Quick setup script for secrets management
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log "Setting up secrets management for NixOS configuration..."

# Initialize secrets management
"$SCRIPT_DIR/manage-secrets.sh" init

# Generate SSH keys
"$SCRIPT_DIR/manage-secrets.sh" setup

log "Secrets management setup complete!"
log ""
log "Next steps:"
log "1. Update your host configuration to enable secrets:"
log "   modules.security.secrets.enable = true;"
log ""
log "2. Apply the configuration:"
log "   sudo nixos-rebuild switch --flake .#<hostname>"
log ""
log "3. Update secrets/secrets.nix with the actual public keys shown above"
log ""
log "4. Create your first secret:"
log "   ./scripts/manage-secrets.sh create user-password-olafkfreund"