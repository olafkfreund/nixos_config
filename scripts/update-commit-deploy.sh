#!/usr/bin/env bash
# update-commit-deploy.sh HOST [SCOPE]
#
# Idiot-proof update flow for NixOS (works for local AND remote targets):
#   1) pre-flight: must be on main, working tree clean (flake.lock OK),
#      and remote target (if any) reachable via SSH
#   2) nix flake update <SCOPE>         (default SCOPE=nixpkgs)
#   3) no-op exit if lock unchanged
#   4) test-build target host closure   (abort commit on build failure)
#   5) commit flake.lock to main + push (ensures lock never gets orphaned)
#   6) switch via `nh os switch` (nice progress UI + auto closure diff):
#        - local  (HOST == $(hostname)): nh os switch --hostname HOST
#        - remote (otherwise): nh os switch --hostname HOST --target-host HOST
#          (builds locally, activates over SSH)
#
# Refuses to run if the working tree has dirty files other than flake.lock —
# that forces unrelated drift to be handled first, avoiding the accidental
# "deploy reverts to origin/main" regression that bit us 2026-04-21.
#
# Usage:
#   ./scripts/update-commit-deploy.sh                    # HOST=$(hostname), nixpkgs
#   ./scripts/update-commit-deploy.sh p620               # default scope, local
#   ./scripts/update-commit-deploy.sh razer              # remote via SSH
#   ./scripts/update-commit-deploy.sh p510 all           # remote, update all inputs
#   ./scripts/update-commit-deploy.sh razer home-manager # remote, one specific input
#
# Remote host requirements:
#   - SSH alias resolvable (~/.ssh/config) or fully-qualified name
#   - ~/.config/nixos is a git clone of this repo with no local edits
#   - sudo without password, or you'll be prompted interactively over SSH
#   - nixosConfigurations.<HOST> exists in flake.nix

set -euo pipefail

HOST="${1:-$(hostname)}"
SCOPE="${2:-nixpkgs}"

# Resolve repo root from script location.
cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"

log() { printf ">> \033[1;34m%s\033[0m\n" "$*"; }
ok() { printf ">> \033[1;32m%s\033[0m\n" "$*"; }
warn() { printf ">> \033[1;33m%s\033[0m\n" "$*" >&2; }
err() {
  printf "!! \033[1;31m%s\033[0m\n" "$*" >&2
  exit 1
}

# --- 1. Safety check ---------------------------------------------------------
log "pre-flight: checking working tree state"

branch=$(git branch --show-current)
if [ "$branch" != "main" ]; then
  err "not on main (currently '$branch'). Switch to main first, or merge."
fi

# Only flake.lock is allowed to be dirty (it may already be pre-bumped).
dirty_others=$(git status --porcelain | awk '$2 != "flake.lock"' || true)
if [ -n "$dirty_others" ]; then
  printf "!! unrelated dirty files present:\n%s\n" "$dirty_others" >&2
  err "clean them up first (commit, stash, or revert) — aborting to avoid drift."
fi

if ! git diff --quiet origin/main -- flake.lock 2>/dev/null; then
  warn "local flake.lock differs from origin/main. Using local version as baseline."
fi

# Decide deploy mode: local if HOST matches this machine's hostname, else SSH.
if [ "$HOST" = "$(hostname)" ]; then
  MODE=local
else
  MODE=remote
  log "pre-flight: SSH reachability check for remote host '$HOST'"
  if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$HOST" true 2>/dev/null; then
    err "cannot reach '$HOST' via SSH. Fix DNS / SSH config / host availability and retry."
  fi
  ok "SSH to $HOST works"
fi

# --- 2. Snapshot pre-update state -------------------------------------------
nixpkgs_node=$(jq -r '.nodes.root.inputs.nixpkgs' flake.lock)
old_rev=$(jq -r --arg n "$nixpkgs_node" '.nodes[$n].locked.rev' flake.lock)
old_date=$(jq -r --arg n "$nixpkgs_node" '.nodes[$n].locked.lastModified | todate' flake.lock)
log "current nixpkgs pin: ${old_rev:0:10} (${old_date})"

# --- 3. Update --------------------------------------------------------------
case "$SCOPE" in
  all)
    log "nix flake update  (all inputs)"
    nix flake update
    ;;
  nixpkgs)
    log "nix flake update nixpkgs"
    nix flake update nixpkgs
    ;;
  *)
    log "nix flake lock --update-input $SCOPE"
    nix flake lock --update-input "$SCOPE"
    ;;
esac

# --- 4. No-op exit ----------------------------------------------------------
if git diff --quiet flake.lock; then
  ok "no lock changes — nothing to commit or deploy."
  exit 0
fi

# --- 5. Show delta summary --------------------------------------------------
new_rev=$(jq -r --arg n "$nixpkgs_node" '.nodes[$n].locked.rev' flake.lock)
new_date=$(jq -r --arg n "$nixpkgs_node" '.nodes[$n].locked.lastModified | todate' flake.lock)

if [ "$old_rev" != "$new_rev" ]; then
  log "nixpkgs: ${old_rev:0:10} (${old_date}) → ${new_rev:0:10} (${new_date})"
else
  log "nixpkgs unchanged (other inputs moved)"
fi

log "flake.lock diff summary:"
git diff --stat flake.lock | head -20

# List which inputs bumped (vs HEAD's lock)
log "inputs bumped:"
git show HEAD:flake.lock >/tmp/.pre-update-lock.json
jq -r --slurpfile orig /tmp/.pre-update-lock.json \
  '.nodes | to_entries[]
   | select(.value.locked.type == "github")
   | . as $n
   | ($orig[0].nodes[$n.key].locked.rev // "none") as $orig_rev
   | select($n.value.locked.rev != $orig_rev)
   | "  \($n.key)  \($orig_rev[0:8]) → \($n.value.locked.rev[0:8])  \($n.value.locked.lastModified | todate)"' \
  flake.lock | sort
rm -f /tmp/.pre-update-lock.json

# --- 6. Test-build target host ---------------------------------------------
log "test-building .#nixosConfigurations.${HOST}.config.system.build.toplevel"
if ! nix build --no-link --print-out-paths \
  ".#nixosConfigurations.${HOST}.config.system.build.toplevel"; then
  err "build failed — lock left dirty for inspection. Fix the issue and retry, or \`git checkout flake.lock\` to cancel."
fi
ok "build succeeded"

# --- 7. Commit + push on main ----------------------------------------------
log "committing flake.lock to main"

# Build a commit message with the nixpkgs delta + scope
msg_subject="chore(flake): bump ${SCOPE} — nixpkgs ${old_rev:0:8} → ${new_rev:0:8}"
if [ "$old_rev" = "$new_rev" ]; then
  msg_subject="chore(flake): bump ${SCOPE} (nixpkgs unchanged)"
fi

git add flake.lock

# --no-verify: pre-commit statix scan hangs on this repo (documented in prior
# PRs); safe because this commit only touches flake.lock.
if ! git commit --no-verify -m "${msg_subject}" \
  -m "Auto-commit from scripts/update-commit-deploy.sh (${HOST}, scope=${SCOPE})." \
  -m "Built and verified against nixosConfigurations.${HOST}." \
  -m "Co-Authored-By: update-commit-deploy <noreply@anthropic.com>"; then
  err "commit failed — aborting before deploy."
fi

log "git push origin main"
if ! git push origin main; then
  err "push failed — abort before deploy so the lock doesn't get orphaned. Fix the push (pull/rebase?) and re-run."
fi
ok "lock committed as $(git rev-parse --short HEAD) and pushed"

# --- 8. Switch (via nh — nice progress UI, unified local/remote) -----------
# `nh os switch` handles:
#   - local deploy with colored progress + automatic closure diff
#   - remote deploy via --target-host (SSH + sudo over the wire)
#   - confirmation prompt before activation
#
# We pass "." as the flake path (current dir). --hostname selects which
# nixosConfigurations.<name> to build.
case "$MODE" in
  local)
    log "nh os switch --hostname ${HOST} .  (local)"
    if ! nh os switch --hostname "$HOST" .; then
      err "local switch failed — commit is on origin/main. Investigate via \`journalctl -xe\` or rollback via \`nh os rollback\`."
    fi
    ;;
  remote)
    # For remote, --target-host routes the activation over SSH. We build
    # locally (this machine, typically p620) and ship the closure rather
    # than burn remote CPU — faster and lets slow hosts (p510) off easy.
    # The --build-host flag is omitted so nh defaults to local build.
    log "nh os switch --hostname ${HOST} --target-host ${HOST} .  (remote, build local)"
    if ! nh os switch --hostname "$HOST" --target-host "$HOST" .; then
      err "remote switch on ${HOST} failed — commit is on origin/main. SSH in and investigate: \`ssh ${HOST} 'journalctl -xe'\` or rollback via \`ssh ${HOST} 'nh os rollback'\`."
    fi
    ;;
esac

ok "done. ${HOST} is now on ${new_rev:0:10} (${new_date})."
