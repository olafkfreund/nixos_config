#!/usr/bin/env bash
# update-antigravity.sh [--check]
#
# Bump every locally-packaged Google Antigravity component to the latest
# version. Single source of truth is the community version tracker
# `Hy4ri/antigravity-flake` (`version.json`), which the repo already
# cross-references — it carries cli / ide / hub / sdk versions + hashes in
# one place and tracks the official auto-updater manifests.
#
# Components WE package (others in the tracker are ignored):
#   cli  -> pkgs/antigravity-cli/default.nix       (`agy`, GCS tarball)
#   ide  -> pkgs/antigravity-ide/package.nix       (Electron IDE, edgedl CDN)
#   sdk  -> pkgs/google-antigravity-py/default.nix (PyPI wheel)
#
# NOT packaged here: `hub` (antigravity-hub). The tracker lists it; if you
# ever add pkgs/antigravity-hub, extend the COMPONENTS table below.
#
# Modes:
#   --check   report current vs latest for each component; exit 1 if any
#             update is available, exit 0 if all current. Edits nothing.
#   (default) rewrite version + url + hash in place for each out-of-date
#             component. Idempotent. Does NOT build, commit, or deploy.
#
# After a default run: build-verify, then commit + deploy on your schedule.
set -euo pipefail

cd "$(dirname "$0")/.."

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

TRACKER="https://raw.githubusercontent.com/Hy4ri/antigravity-flake/main/version.json"

log() { printf ">> \033[1;34m%s\033[0m\n" "$*"; }
ok() { printf ">> \033[1;32m%s\033[0m\n" "$*"; }
warn() { printf ">> \033[1;33m%s\033[0m\n" "$*" >&2; }
die() {
  printf "!! \033[1;31m%s\033[0m\n" "$*" >&2
  exit 1
}

command -v jq >/dev/null || die "jq not found"
command -v curl >/dev/null || die "curl not found"

log "fetching version tracker: $TRACKER"
VJSON="$(curl -fsSL --max-time 30 "$TRACKER")" || die "could not fetch tracker version.json"

# to_sri <nix32-or-sri-hash> : normalise any hash to SRI sha256
to_sri() {
  local h="$1"
  case "$h" in
    sha256-*) printf '%s' "$h" ;;
    *) nix hash convert --hash-algo sha256 --to sri "$h" 2>/dev/null \
      || nix hash to-sri --type sha256 "$h" ;;
  esac
}

# current_version <file> : the `version = "...";` value
current_version() { grep -m1 -oE 'version = "[^"]*"' "$1" | sed -E 's/version = "([^"]*)"/\1/'; }

# rewrite_pkg <file> <new_version> <new_url> <new_sri>
# Replaces the version line and the fetchurl url+hash block in place.
rewrite_pkg() {
  python3 - "$@" <<'PY'
import re, sys
f, ver, url, sri = sys.argv[1:5]
s = open(f).read()
s, nv = re.subn(r'version = "[^"]*";', f'version = "{ver}";', s, count=1)
# Replace the first `url = "...";` followed (any whitespace) by `hash = "...";`
s, nb = re.subn(r'url = "[^"]*";(\s*)hash = "[^"]*";',
                f'url = "{url}";\\1hash = "{sri}";', s, count=1)
if nv != 1 or nb != 1:
    sys.exit(f"rewrite failed for {f} (version subs={nv}, url/hash subs={nb})")
open(f, 'w').write(s)
PY
}

# --- component definitions -------------------------------------------------
# Each: tracker-key | nix file | url template (uses $V) | tracker hash path
declare -A FILE URLT HASHKEY
COMPONENTS=(cli ide sdk)

# URLT[*] carry a literal `__V__` token, replaced with the resolved version
# below via bash substitution (no eval).
FILE[cli]="pkgs/antigravity-cli/default.nix"
URLT[cli]="https://storage.googleapis.com/antigravity-public/antigravity-cli/__V__/linux-x64/cli_linux_x64.tar.gz"
HASHKEY[cli]='.cli.hashes."x86_64-linux"'

FILE[ide]="pkgs/antigravity-ide/package.nix"
URLT[ide]="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/__V__/linux-x64/Antigravity%20IDE.tar.gz"
HASHKEY[ide]='.ide.hashes."x86_64-linux"'

FILE[sdk]="pkgs/google-antigravity-py/default.nix"
URLT[sdk]='' # sdk url comes straight from the tracker (PyPI wheel)
HASHKEY[sdk]='.sdk.hashes."x86_64-linux"'

updates=0
printf "\n%-6s %-26s %-26s %s\n" "COMP" "CURRENT" "LATEST" "STATUS"
printf "%-6s %-26s %-26s %s\n" "----" "-------" "------" "------"

declare -A NEWVER NEWURL NEWSRI
for c in "${COMPONENTS[@]}"; do
  file="${FILE[$c]}"
  [ -f "$file" ] || {
    warn "$c: $file missing — skipping"
    continue
  }
  cur="$(current_version "$file")"
  latest="$(jq -r ".${c}.version" <<<"$VJSON")"
  [ "$latest" = "null" ] && {
    warn "$c: not in tracker — skipping"
    continue
  }

  if [ "$cur" = "$latest" ]; then
    printf "%-6s %-26s %-26s %s\n" "$c" "$cur" "$latest" "current"
    continue
  fi
  updates=$((updates + 1))
  printf "%-6s %-26s %-26s %s\n" "$c" "$cur" "$latest" "UPDATE"

  # resolve url
  if [ "$c" = "sdk" ]; then
    url="$(jq -r '.sdk.urls."x86_64-linux"' <<<"$VJSON")"
  else
    url="${URLT[$c]//__V__/$latest}"
  fi
  sri="$(to_sri "$(jq -r "${HASHKEY[$c]}" <<<"$VJSON")")"
  [ -n "$url" ] && [ -n "$sri" ] || die "$c: could not resolve url/hash"
  NEWVER[$c]="$latest"
  NEWURL[$c]="$url"
  NEWSRI[$c]="$sri"
done
echo

# tracker also tracks `hub` (not packaged here) — surface it as info only
HUB="$(jq -r '.hub.version // empty' <<<"$VJSON")"
[ -n "$HUB" ] && log "tracker also lists hub=$HUB (not packaged in this repo — ignored)"

if [ "$updates" -eq 0 ]; then
  ok "all packaged antigravity components are current — nothing to do"
  exit 0
fi

if [ "$CHECK" -eq 1 ]; then
  warn "$updates update(s) available — re-run without --check to apply"
  exit 1
fi

for c in "${COMPONENTS[@]}"; do
  [ -n "${NEWVER[$c]:-}" ] || continue
  log "rewriting ${FILE[$c]} -> ${NEWVER[$c]}"
  rewrite_pkg "${FILE[$c]}" "${NEWVER[$c]}" "${NEWURL[$c]}" "${NEWSRI[$c]}"
done

ok "applied $updates update(s). Next:"
cat <<EOF

  # build-verify (current host; skip p510 — not an antigravity host)
  HOST=\$(hostname)
  nix build --no-link .#nixosConfigurations.\$HOST.config.system.build.toplevel

  # commit + deploy on your schedule
  git add pkgs/antigravity-cli pkgs/antigravity-ide pkgs/google-antigravity-py
  git commit --no-verify -m "chore(antigravity): bump packages"
  nhs \$HOST     # or: nh os switch --hostname \$HOST .
EOF
