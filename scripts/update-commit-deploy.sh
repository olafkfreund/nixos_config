#!/usr/bin/env bash
# update-commit-deploy.sh HOST [SCOPE]
#
# Idiot-proof update flow for NixOS (works for local AND remote targets):
#   1) pre-flight: must be on main, working tree clean (flake.lock OK),
#      and remote target (if any) reachable via SSH
#   2) nix flake update <SCOPE>         (default SCOPE=all — recommended;
#      always pull latest of every input, otherwise you risk shipping a
#      stale lock from a checkout that's behind main)
#   3) splice nixpkgs + nixpkgs-unstable from GitHub ground truth
#   4) no-op exit if lock unchanged AND host already current
#   5) test-build target host closure   (abort commit on build failure)
#   6) feature-branch + OPEN PR for flake.lock (NOT YET MERGED — merge is
#      deferred until the host passes the post-deploy health check below)
#   7) snapshot target's current generation symlink (for potential rollback)
#   8) switch via `nh os switch` (nice progress UI + auto closure diff):
#        - local  (HOST == $(hostname)): nh os switch --hostname HOST
#        - remote (otherwise): nh os switch --hostname HOST --target-host HOST
#          (builds locally, activates over SSH)
#   9) post-deploy health check via scripts/health-checks/${HOST}.sh
#       (executed on the target — locally or piped over SSH for remote)
#  10) IF health passed: squash-merge the open PR + pull main
#      IF health failed: rollback target to the snapshotted generation
#                        AND close the PR + delete branch
#                        AND discard the local flake.lock change so the
#                        next deploy re-fetches upstream fresh
#
# Step 9 is the layer that catches upstream regressions that build cleanly
# AND activate cleanly but leave the host non-functional — the 2026-06-08
# mesa 26.1.1 / GNOME 50.0 silent compositor crash on Optimus PRIME-sync
# is the motivating case (see commit d62a86f80 + post-mortem).
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

# --- Argument parsing -------------------------------------------------------
# Positional args: HOST [SCOPE]. Flag --no-deploy can appear anywhere.
# --no-deploy: run update + build + commit + PR-merge but skip the final
# `nh os switch`. Use this to prepare a deploy while the target host is
# offline; later run `nhs HOST` (or this same script without --no-deploy)
# when it's reachable — the build will be a cache hit, only copy+activate
# remains. See docs/UPDATE-DEPLOY.md.
NO_DEPLOY=0
positional=()
for arg in "$@"; do
  case "$arg" in
    --no-deploy) NO_DEPLOY=1 ;;
    --*)
      printf "!! unknown flag: %s\n" "$arg" >&2
      exit 2
      ;;
    *) positional+=("$arg") ;;
  esac
done
HOST="${positional[0]:-$(hostname)}"
SCOPE="${positional[1]:-all}"

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
  if [ $NO_DEPLOY -eq 0 ]; then
    log "pre-flight: SSH reachability check for remote host '$HOST'"
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$HOST" true 2>/dev/null; then
      err "cannot reach '$HOST' via SSH. Fix DNS / SSH config / host availability and retry."
    fi
    ok "SSH to $HOST works"
  else
    log "skipping SSH reachability check (--no-deploy: target may be offline)"
  fi
fi

# --- 2. Snapshot pre-update state -------------------------------------------
nixpkgs_node=$(jq -r '.nodes.root.inputs.nixpkgs' flake.lock)
old_rev=$(jq -r --arg n "$nixpkgs_node" '.nodes[$n].locked.rev' flake.lock)
old_date=$(jq -r --arg n "$nixpkgs_node" '.nodes[$n].locked.lastModified | todate' flake.lock)
log "current nixpkgs pin: ${old_rev:0:10} (${old_date})"

# --- 3. Update --------------------------------------------------------------
# Two-stage update because `nix flake update` cannot be trusted with the
# nixpkgs family on this machine. Empirically:
#
#  - Bulk `nix flake update` may rewrite BOTH nixpkgs.locked.rev AND
#    nixpkgs.original.ref to stale values (saw "nixos-unstable" silently
#    revert to "nixos-25.05" with locked.rev sliding back 10 months).
#  - `nix flake update nixpkgs --refresh` (named + refresh) sometimes works
#    sometimes doesn't, depending on what's in ~/.cache/nix/fetcher-cache-v4.
#  - Even a regression-guard against HEAD's lastModified couldn't reliably
#    catch every shape of regression because it doesn't cover `original.ref`.
#
# So: run bulk update for the cheap inputs, then forcibly splice nixpkgs +
# nixpkgs-unstable with GROUND TRUTH from github via `gh api` (bypasses
# every nix cache). This is bulletproof regardless of nix's internal state.
case "$SCOPE" in
  all)
    log "nix flake update  (all inputs, bulk)"
    nix flake update
    ;;
  nixpkgs)
    :
    ;; # nixpkgs ground-truth splice below covers it
  nixpkgs-unstable)
    :
    ;; # ditto
  *)
    log "nix flake update $SCOPE --refresh"
    nix flake update "$SCOPE" --refresh
    ;;
esac

# --- 3b. Force nixpkgs + nixpkgs-unstable to GitHub ground truth ------------
#
# Always do this after the bulk update — overwrites any cache-stale rev,
# wrong `original.ref`, or quietly-reverted owner casing.
splice_nixpkgs_node() {
  local node="$1"
  local sha
  sha=$(gh api 'repos/NixOS/nixpkgs/branches/nixos-unstable' --jq '.commit.sha' 2>/dev/null) \
    || {
      warn "could not fetch github nixos-unstable HEAD via gh api; skipping splice for ${node}"
      return 0
    }
  # Get a fresh narHash via the explicit-SHA URL (always works regardless of cache).
  local meta nar lm
  meta=$(nix flake metadata "github:NixOS/nixpkgs/${sha}" --refresh --json 2>/dev/null) \
    || {
      warn "nix flake metadata failed for ${sha}; skipping splice for ${node}"
      return 0
    }
  nar=$(printf '%s' "$meta" | jq -r '.locked.narHash')
  lm=$(printf '%s' "$meta" | jq -r '.locked.lastModified')
  log "splicing ${node} = github:nixos/nixpkgs/${sha:0:10} (lastModified $(date -u -d @${lm} +%Y-%m-%d))"
  jq --arg n "$node" --arg sha "$sha" --arg nar "$nar" --argjson lm "$lm" '
    .nodes[$n].locked = {
      lastModified: $lm, narHash: $nar,
      owner: "nixos", repo: "nixpkgs", rev: $sha, type: "github"
    } |
    .nodes[$n].original = {
      owner: "nixos", ref: "nixos-unstable", repo: "nixpkgs", type: "github"
    }
  ' flake.lock >flake.lock.tmp && mv flake.lock.tmp flake.lock
}

splice_nixpkgs_node nixpkgs
splice_nixpkgs_node nixpkgs-unstable

# --- 4. Determine LOCK_CHANGED flag -----------------------------------------
LOCK_CHANGED=0
if ! git diff --quiet flake.lock; then
  LOCK_CHANGED=1
fi

# --- 5. Freshness check: is HOST already on the closure our lock would build?
# Use `nix eval --raw` to get the expected outPath WITHOUT triggering a build —
# cheap probe that tells us if the target is stale. We only do the expensive
# full build if we actually need to deploy.
log "freshness check: evaluating expected closure for ${HOST}"
expected=$(nix eval --raw \
  ".#nixosConfigurations.${HOST}.config.system.build.toplevel.outPath" 2>/dev/null) \
  || err "could not eval target closure outPath. Is ${HOST} listed in nixosConfigurations?"

case "$MODE" in
  local) current=$(readlink /run/current-system 2>/dev/null || echo "") ;;
  remote) current=$(ssh "$HOST" 'readlink /run/current-system' 2>/dev/null || echo "") ;;
esac

HOST_STALE=0
if [ -z "$current" ]; then
  warn "could not read ${HOST}'s /run/current-system (first-time deploy?); will deploy anyway"
  HOST_STALE=1
elif [ "$expected" != "$current" ]; then
  HOST_STALE=1
fi

# --- 6. Nothing-to-do exit --------------------------------------------------
if [ $LOCK_CHANGED -eq 0 ] && [ $HOST_STALE -eq 0 ]; then
  ok "no lock changes AND ${HOST} already on ${expected##*/} — nothing to do."
  exit 0
fi

# In --no-deploy mode the deploy isn't happening, so HOST_STALE alone isn't
# reason to do work — only the lock matters. (Without this, an unreachable
# host short-circuits to HOST_STALE=1, which would trigger a wasted build.)
if [ $NO_DEPLOY -eq 1 ] && [ $LOCK_CHANGED -eq 0 ]; then
  ok "no lock changes — nothing to prebuild (--no-deploy)."
  exit 0
fi

# --- 7. Show what's happening -----------------------------------------------
if [ $LOCK_CHANGED -eq 1 ]; then
  new_rev=$(jq -r --arg n "$nixpkgs_node" '.nodes[$n].locked.rev' flake.lock)
  new_date=$(jq -r --arg n "$nixpkgs_node" '.nodes[$n].locked.lastModified | todate' flake.lock)
  if [ "$old_rev" != "$new_rev" ]; then
    log "nixpkgs: ${old_rev:0:10} (${old_date}) → ${new_rev:0:10} (${new_date})"
  else
    log "nixpkgs unchanged (other inputs moved)"
  fi
  log "flake.lock diff summary:"
  git diff --stat flake.lock | head -20
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
else
  new_rev="$old_rev"
  new_date="$old_date"
  log "lock unchanged — but ${HOST} is stale (running ${current##*/}); deploying current state"
fi

# --- 8. Full build of target closure (validates + warms cache) --------------
#
# Build where the command is run — if you want p620's beefy CPU, just run
# `nhs` or `just update-commit-deploy` from p620. Running from razer/p510
# builds locally on that host (no cross-host routing — see docs/UPDATE-DEPLOY.md).
#
# Use `nh os build` (not plain `nix build`) so the user sees nh's progress
# UI consistently with the later deploy step. --dry (exists) would be too
# light; we need a real build to catch eval + build-time failures BEFORE
# committing the lock.
log "nh os build --hostname ${HOST} .  (validates closure before commit)"
if ! nh os build --hostname "$HOST" .; then
  if [ $LOCK_CHANGED -eq 1 ]; then
    err "build failed — lock left dirty for inspection. Fix the issue and retry, or \`git checkout flake.lock\` to cancel."
  else
    err "build failed — nothing was committed; investigate before retrying."
  fi
fi
ok "build succeeded"

# --- 9. Commit + open PR (NOT MERGED YET — merge is step 12) ---------------
# Branch protection on `main` requires changes to land via PR. Direct push
# was rejected starting 2026-04-26 (PR #359 / #361 / #362 all hit this).
# We branch, commit, push the branch, and open a PR via `gh pr create`.
# The squash-merge is deferred to step 12 — it only fires after the post-
# deploy health check (step 11) passes. If health fails, step 12 instead
# closes this PR and discards the local lock change, so a broken upstream
# never lands on main.
if [ $LOCK_CHANGED -eq 1 ]; then
  # Build a commit message with the nixpkgs delta + scope
  msg_subject="chore(flake): bump ${SCOPE} — nixpkgs ${old_rev:0:8} → ${new_rev:0:8}"
  if [ "$old_rev" = "$new_rev" ]; then
    msg_subject="chore(flake): bump ${SCOPE} (nixpkgs unchanged)"
  fi

  branch_name="chore/lock-bump-${SCOPE//\//-}-${new_rev:0:8}"
  log "creating branch ${branch_name}"
  if git show-ref --quiet "refs/heads/${branch_name}"; then
    err "branch ${branch_name} already exists locally. Delete it (\`git branch -D ${branch_name}\`) and retry."
  fi
  git checkout -b "${branch_name}"

  git add flake.lock

  # --no-verify: pre-commit statix scan hangs on this repo (documented in prior
  # PRs); safe because this commit only touches flake.lock.
  if ! git commit --no-verify -m "${msg_subject}" \
    -m "Auto-commit from scripts/update-commit-deploy.sh (${HOST}, scope=${SCOPE})." \
    -m "Built and verified against nixosConfigurations.${HOST}." \
    -m "Co-Authored-By: update-commit-deploy <noreply@anthropic.com>"; then
    git checkout main
    git branch -D "${branch_name}" 2>/dev/null || true
    err "commit failed — aborting before deploy."
  fi

  log "pushing branch ${branch_name}"
  if ! git push -u origin "${branch_name}"; then
    git checkout main
    git branch -D "${branch_name}" 2>/dev/null || true
    err "branch push failed (maybe an orphan branch with the same name exists on origin? \`gh api -X DELETE repos/:owner/:repo/git/refs/heads/${branch_name}\` to clean up)."
  fi

  log "opening PR"
  if ! pr_url=$(gh pr create --base main --head "${branch_name}" \
    --title "${msg_subject}" \
    --body "Auto-PR from \`scripts/update-commit-deploy.sh\` (target=${HOST}, scope=${SCOPE}).

Built and verified locally against nixosConfigurations.${HOST} before opening this PR.

🤖 Generated with [Claude Code](https://claude.com/claude-code)" 2>&1 | tail -1); then
    git checkout main
    err "gh pr create failed: ${pr_url}"
  fi
  log "PR opened: ${pr_url}"
  log "merge deferred until post-deploy health check passes"

  # Surface PR + branch handles to the rollback/finalize code below.
  PR_URL="${pr_url}"
  BRANCH_NAME="${branch_name}"
else
  log "skipping commit/push (lock unchanged); deploying existing state to ${HOST}"
  PR_URL=""
  BRANCH_NAME=""
fi

# --- 10. Switch (via nh — nice progress UI, unified local/remote) ----------
# `nh os switch` handles:
#   - local deploy with colored progress + automatic closure diff
#   - remote deploy via --target-host (SSH + sudo over the wire)
#   - confirmation prompt before activation
#
# We pass "." as the flake path (current dir). --hostname selects which
# nixosConfigurations.<name> to build.
# All our hosts (p620, razer, p510) are configured with NOPASSWD: ALL for
# olafkfreund. Pass --elevation-strategy passwordless so nh never tries to
# prompt for a sudo password on the remote — otherwise nh's default 'auto'
# strategy can still block on a TTY prompt even with NOPASSWD configured.
ELEV=(--elevation-strategy passwordless)

# Build-host policy: always build on the LOCAL machine (wherever the command
# was invoked from). Intentionally NOT routing builds through p620, because
# you might run this from razer while traveling with no network to p620.
# If you want p620 to do the heavy lifting, run `nhs` from p620.

# Try `nh os switch`. If it fails specifically because a critical-component
# change (e.g. dbus → dbus-broker, init system swap, kernel ABI break) tripped
# the NixOS pre-switch inhibitor, fall back to `nh os boot` so the new system
# is staged for next boot — and tell the user to reboot.
#
# Without this fallback, the deploy fails AFTER the lock is already on main,
# leaving the user to run a separate `nh os boot` manually. After the user
# reboots once, the inhibiting change is "done" and future `switch` calls
# work normally — this is a one-time pain per critical change.
nh_switch_or_boot() {
  # Args: nh os switch arguments (e.g. --hostname razer [--target-host razer] .)
  local out rc
  out=$(mktemp)
  set +e
  nh os switch "${ELEV[@]}" "$@" 2>&1 | tee "$out"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -ne 0 ] && grep -qE "switchInhibitors|Pre-switch checks failed" "$out"; then
    warn "switch refused: a critical-component change requires a reboot."
    log "falling back to: nh os boot $*"
    if ! nh os boot "${ELEV[@]}" "$@"; then
      rm -f "$out"
      err "boot fallback also failed — investigate."
    fi
    rm -f "$out"
    warn "============================================================"
    warn "REBOOT REQUIRED on ${HOST} to complete this deployment."
    warn "Run:  ssh ${HOST} 'sudo systemctl reboot'   (or local reboot)"
    warn "============================================================"
    return 0
  fi
  rm -f "$out"
  return "$rc"
}

# Print an explicit Added / Removed / Upgraded package report via nvd.
#
# nh's own `--diff` is `auto`: it prints a version-level table for LOCAL
# switches but SKIPS it entirely for remote (--target-host) deploys, and it
# only lists name-version changes (a nixpkgs-unchanged lock bump shows just a
# size delta). We want a reliable "what was installed / upgraded / removed"
# view on EVERY deploy — so diff the pre-switch generation ($1) against the new
# closure ($2) with nvd directly. Both paths exist on the target after the
# switch (nh --target-host copies the closure across), and nvd ships in every
# host's system closure.
show_pkg_diff() {
  local old="$1" new="$2"
  if [ -z "$old" ]; then
    warn "no previous generation captured — skipping package diff (first-time deploy?)"
    return 0
  fi
  if [ "$old" = "$new" ]; then
    log "package diff: closure unchanged (nothing added / removed / upgraded)."
    return 0
  fi
  log "package changes on ${HOST} (nvd — added / removed / upgraded):"
  printf '\033[2m%s\033[0m\n' "------------------------------------------------------------"
  case "$MODE" in
    local) nvd diff "$old" "$new" || warn "nvd diff failed (non-fatal)" ;;
    remote) ssh "$HOST" "nvd diff '$old' '$new'" || warn "remote nvd diff failed (non-fatal)" ;;
  esac
  printf '\033[2m%s\033[0m\n' "------------------------------------------------------------"
}

# --no-deploy: build is done, lock is on a feature branch + PR is OPEN but
# UNMERGED (since merge is gated on the post-deploy health check that we're
# now skipping). Tell the user. The cached closure means stage 2 — the
# follow-up `nhs HOST` run when the target is reachable — is a fast copy +
# activate + health-check + merge.
if [ $NO_DEPLOY -eq 1 ]; then
  ok "prebuild complete; closure cached locally."
  if [ -n "${PR_URL:-}" ]; then
    warn "PR ${PR_URL} is OPEN but UNMERGED (merge happens after a passing health check on a real deploy)."
    log "branch: ${BRANCH_NAME}"
  fi
  log "to deploy when ${HOST} is reachable, run:  nhs ${HOST}"
  log "  (build will be a cache hit; only copy + activate + health-check + merge remains)"
  exit 0
fi

# --- 10b. Snapshot current generation for rollback -------------------------
# `readlink -f /nix/var/nix/profiles/system` resolves to the absolute store
# path of the active system derivation. We use that path directly with
# switch-to-configuration if we need to revert — bypassing nh/nixos-rebuild
# entirely so the rollback can't fail on stale flake state.
log "snapshotting current generation on ${HOST} (for potential rollback)"
case "$MODE" in
  local) OLD_GEN_PATH=$(readlink -f /nix/var/nix/profiles/system) ;;
  remote) OLD_GEN_PATH=$(ssh "$HOST" 'readlink -f /nix/var/nix/profiles/system') ;;
esac
if [ -z "${OLD_GEN_PATH:-}" ]; then
  err "could not read ${HOST}'s current generation symlink — refusing to deploy without a rollback anchor"
fi
log "current generation: ${OLD_GEN_PATH##*/}"

# Rollback path. Used both when nh os switch itself returns non-zero AND
# when the post-deploy health check fails. Restores the target to
# OLD_GEN_PATH, closes the unmerged PR, returns the local checkout to main,
# discards the dirty flake.lock so the next run re-pulls upstream fresh,
# then exits 1.
rollback_and_close_pr() {
  local reason="$1"
  local rc=0
  warn "============================================================"
  warn "DEPLOY FAILED: ${reason}"
  warn "============================================================"

  if [ -n "${OLD_GEN_PATH:-}" ]; then
    log "rolling back ${HOST} → ${OLD_GEN_PATH##*/}"
    set +e
    case "$MODE" in
      local) sudo "${OLD_GEN_PATH}/bin/switch-to-configuration" switch ;;
      remote) ssh "$HOST" "sudo ${OLD_GEN_PATH}/bin/switch-to-configuration switch" ;;
    esac
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
      warn "rollback switch-to-configuration returned ${rc} — a reboot of ${HOST} will still recover (boot default is unchanged because we used \`nh os switch\`, not \`nh os boot\`, only when switch succeeded)"
    else
      ok "${HOST} rolled back"
    fi
  fi

  if [ -n "${PR_URL:-}" ]; then
    log "closing unmerged PR ${PR_URL}"
    set +e
    gh pr close "${PR_URL}" --delete-branch \
      --comment "Auto-closed: post-deploy health check failed on ${HOST}. Lock NOT landed on main; the next \`nhs ${HOST}\` will re-pull upstream from scratch."
    set -e
    PR_URL=""
  fi

  # Return checkout to clean main. We're sitting on ${BRANCH_NAME} with a
  # dirty flake.lock (the bump that just got rejected). Discard both so a
  # re-run is genuinely fresh.
  log "discarding local flake.lock change and returning to main"
  set +e
  git checkout main 2>/dev/null
  if [ -n "${BRANCH_NAME:-}" ]; then
    git branch -D "${BRANCH_NAME}" 2>/dev/null
  fi
  git checkout -- flake.lock 2>/dev/null
  set -e

  err "deploy aborted; ${HOST} rolled back. Re-run after upstream regression clears."
}

# --- 10c. Switch -----------------------------------------------------------
case "$MODE" in
  local)
    log "nh os switch --hostname ${HOST} .  (local target, local build)"
    # -d always: force nh's native package+version diff (correct baseline for
    # local — compares this host's current-system vs the new closure).
    if ! nh_switch_or_boot --diff always --hostname "$HOST" .; then
      rollback_and_close_pr "local nh os switch failed (see output above)"
    fi
    ;;
  remote)
    # For remote targets, --target-host routes the activation over SSH.
    # Build happens on this machine, closure ships via SSH.
    log "nh os switch --hostname ${HOST} --target-host ${HOST} .  (remote target, local build)"
    # -d never: nh's remote diff compares the LOCAL system against the remote
    # closure (wrong baseline — shows this host's packages as removed). Suppress
    # it; the correct remote diff (target-old vs target-new) is done by nvd in
    # show_pkg_diff below.
    if ! nh_switch_or_boot --diff never --hostname "$HOST" --target-host "$HOST" .; then
      rollback_and_close_pr "remote nh os switch on ${HOST} failed (see output above)"
    fi
    ;;
esac

# --- 10d. Package diff: what was installed / upgraded / removed ------------
# LOCAL deploys already got nh's native diff (-d always above). For REMOTE,
# nh's diff is suppressed (wrong baseline), so produce the correct one here:
# nvd on the TARGET, comparing its old generation ($current) vs the new closure.
if [ "$MODE" = "remote" ]; then
  show_pkg_diff "$current" "$expected"
fi

# --- 11. Post-deploy health check -----------------------------------------
#
# Catches upstream regressions that pass build + activate but leave the host
# non-functional (the motivating 2026-06-08 mesa/GNOME silent crash). Health
# check scripts live in scripts/health-checks/<HOST>.sh and exit 0 = healthy.
#
# Skip if `nh os switch` fell back to `nh os boot` (the new gen isn't
# running, only staged for next boot) — detected by comparing the running
# /run/current-system against the expected closure path.
log "verifying which generation is now running on ${HOST}"
case "$MODE" in
  local) current_now=$(readlink /run/current-system) ;;
  remote) current_now=$(ssh "$HOST" 'readlink /run/current-system') ;;
esac

RUN_HEALTH_CHECK=1
if [ "$current_now" != "$expected" ]; then
  warn "running gen (${current_now##*/}) != expected (${expected##*/})"
  warn "  → switch was deferred to next boot (pre-switch inhibitor)"
  warn "  → skipping health check; PR will merge anyway because the BUILD is good"
  warn "  → reboot ${HOST} and verify manually, then run the next deploy"
  RUN_HEALTH_CHECK=0
fi

if [ "$RUN_HEALTH_CHECK" -eq 1 ]; then
  HEALTH_SCRIPT="${REPO_ROOT}/scripts/health-checks/${HOST}.sh"
  if [ -x "$HEALTH_SCRIPT" ]; then
    log "post-deploy: waiting 15s for services to settle before health check"
    sleep 15
    log "running scripts/health-checks/${HOST}.sh on ${HOST}"
    set +e
    case "$MODE" in
      local) bash "$HEALTH_SCRIPT" ;;
      remote) ssh "$HOST" 'bash -s' <"$HEALTH_SCRIPT" ;;
    esac
    health_rc=$?
    set -e
    if [ "$health_rc" -ne 0 ]; then
      rollback_and_close_pr "scripts/health-checks/${HOST}.sh returned ${health_rc} on ${HOST}"
    fi
    ok "health check passed"
  else
    warn "no health check script at scripts/health-checks/${HOST}.sh"
    warn "  → deploy cannot be verified; consider adding one (see existing scripts as templates)"
  fi
fi

# --- 12. Finalize: squash-merge the PR (lock lands on main) ---------------
if [ -n "${PR_URL:-}" ]; then
  log "health check passed (or skipped) — squash-merging PR ${PR_URL}"
  if ! gh pr merge "${PR_URL}" --squash --delete-branch; then
    warn "PR merge failed — ${HOST} is on the new generation but the lock is NOT on main."
    warn "  PR still open at: ${PR_URL}"
    warn "  Manual fix: merge via the UI, then  git checkout main && git pull --ff-only origin main"
  else
    log "syncing local main"
    git checkout main
    if ! git pull --ff-only origin main; then
      err "could not fast-forward local main after merge. Resolve manually and re-run."
    fi
    ok "lock landed as $(git rev-parse --short HEAD) (via merged ${PR_URL})"
  fi
fi

ok "done. ${HOST} is now on ${new_rev:0:10} (${new_date})."
