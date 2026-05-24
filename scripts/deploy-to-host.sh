#!/usr/bin/env bash
# deploy-to-host — TTY-safe wrapper around `nixos-rebuild --target-host` for
# cross-host activation from a non-interactive context (background tasks, CI,
# automation).
#
# Why this exists: `nh os switch --target-host HOST` invokes sudo on the
# remote unconditionally trying to read a password, which requires a TTY.
# Even with NOPASSWD configured on the remote, nh fails with
#
#   Error: Failed to read sudo password / The input device is not a TTY
#
# whenever run from a non-interactive shell. `nixos-rebuild --target-host
# --use-remote-sudo` handles this correctly — it uses sudo's -S mode and
# doesn't need a TTY when NOPASSWD applies.
#
# Use this instead of `nh os switch --target-host HOST` whenever the caller
# might not have a TTY (background jobs, CI, scripted automation). For
# interactive use from your terminal, nh still works fine.
#
# Usage:
#   ./scripts/deploy-to-host.sh <HOST>          # build + switch on remote
#   ./scripts/deploy-to-host.sh <HOST> build    # build only, no activation
#   ./scripts/deploy-to-host.sh <HOST> boot     # activate on next boot only
#   ./scripts/deploy-to-host.sh <HOST> dry      # plan only, no changes
#
# Example:
#   ./scripts/deploy-to-host.sh p510
#   ./scripts/deploy-to-host.sh razer build

set -u

die() {
  echo "error: $*" >&2
  exit 1
}
log() { echo ">> $*" >&2; }

# ---- args ----

HOST="${1:-}"
ACTION="${2:-switch}"

[ -n "$HOST" ] || die "usage: $0 <HOST> [switch|build|boot|dry]"

case "$ACTION" in
  switch | build | boot)
    ;;
  dry)
    ACTION="dry-build"
    ;;
  *)
    die "unknown action '$ACTION' (expected: switch | build | boot | dry)"
    ;;
esac

# ---- preflight ----

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$REPO_ROOT/flake.nix" ] || die "no flake.nix at $REPO_ROOT"

if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$HOST" "true" 2>/dev/null; then
  die "host '$HOST' unreachable via SSH (BatchMode, no password). " \
    "Check ~/.ssh/config and that your key is authorized on the target."
fi

# Sanity: confirm NOPASSWD sudo is actually live on the target so we don't
# silently hang waiting for a password later.
if ! ssh -o BatchMode=yes "$HOST" "sudo -n true" 2>/dev/null; then
  die "host '$HOST' does not have NOPASSWD sudo for the SSH user. " \
    "Either fix security.sudo.wheelNeedsPassword on the host, or run " \
    "this from a real terminal so sudo can prompt."
fi

# ---- deploy ----

log "deploying ${REPO_ROOT}#${HOST} to ${HOST} (action=${ACTION})"
log "command: nixos-rebuild ${ACTION} --target-host olafkfreund@${HOST} --sudo --flake ${REPO_ROOT}#${HOST}"

cd "$REPO_ROOT" || die "cannot cd to $REPO_ROOT"
exec nixos-rebuild "$ACTION" \
  --target-host "olafkfreund@$HOST" \
  --sudo \
  --flake "$REPO_ROOT#$HOST"
